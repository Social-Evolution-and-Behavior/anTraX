from os import listdir
from os.path import isfile, join
import tensorflow as tf
from tensorflow import Graph, Session
from tensorflow import keras
from tensorflow.keras import backend as K
from tensorflow.keras.preprocessing import image
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
import h5py
import numpy as np
import os
import csv
import shutil
from tempfile import mkdtemp

import queue
import threading

from PIL import Image
from glob import glob
from sklearn.utils import class_weight
from sklearn.metrics import confusion_matrix, classification_report
from datetime import datetime
import pandas as pd

from .experiment import *
from .utils import *
from .models import new_model


AMBIG_CLASSES = ['Unknown', '??', 'MultiAnt', 'Multi', 'multi']
MULTI_CLASSES = ['MultiAnt', 'Multi', 'multi']
NONANT_CLASSES = ['NoAnt', 'FOOD', 'Larva']

K.clear_session()



def get_thread_model(modelfile):

    thread_model = {}
    g = Graph()
    with g.as_default():
        thread_model['session'] = Session()
        with thread_model['session'].as_default():
            thread_model['model'] = keras.models.load_model(modelfile)
            thread_model['graph'] = tf.get_default_graph()

    return thread_model


class axClassifier:

    @staticmethod
    def is_modelfile(file):
        pass

    @staticmethod
    def is_modeldir(file):
        pass

    @staticmethod
    def load(modelfile):

        model = keras.models.load_model(modelfile)
        model._make_predict_function()

        with h5py.File(modelfile, 'r') as f:
            prmtrs = json.loads(f['prmtrs'][()])
            try:
                classes = [x[0].decode() for x in f['classes'][()]]
            except:
                print('-W- Cannot read classes')
                classes = None

        c = axClassifier(name=None, nclasses=None, loaded=True, prmtrs=prmtrs, classes=classes, model=model)
        c.modelfile = modelfile

        if c.classes is not None:
            c.trained = True

        if 'unknown_weight' not in c.prmtrs:
            c.prmtrs['unknown_weight'] = 20

        if 'multi_weight' not in c.prmtrs:
            c.prmtrs['multi_weight'] = 0.1

        if 'crop_size' not in c.prmtrs:
            c.prmtrs['crop_size'] = None

        if 'hsymmetry' not in c.prmtrs:
            c.prmtrs['hsymmetry'] = True

        report('I', 'Loaded classifier from ' + modelfile)

        return c

    def __init__(self,
                 name,
                 nclasses,
                 modeltype='small',
                 json=None,
                 loss='categorical_crossentropy',
                 optimizer='adam',
                 metrics=['accuracy'],
                 background='white',
                 consv_factor=0.5,
                 use_min_conf=True,
                 examplesdir=None,
                 target_size=64,
                 crop_size=None,
                 unknown_weight=20,
                 multi_weight=0.1,
                 scale=1,
                 loaded=False,
                 model=None,
                 prmtrs=None,
                 hsymmetry=False,
                 classes=None):

        if loaded:
            self.prmtrs = prmtrs
            self.model = model
            self.classes = classes

        else:
            # classifier parameters
            self.prmtrs = {}
            self.prmtrs['name'] = name
            self.prmtrs['nclasses'] = nclasses
            self.prmtrs['modeltype'] = modeltype
            self.prmtrs['json'] = json
            self.prmtrs['use_min_conf'] = use_min_conf
            self.prmtrs['consv_factor'] = consv_factor
            self.prmtrs['min_conf'] = 1 - 0.2 * consv_factor
            self.prmtrs['min_conf_short'] = 1 - 0.02 * consv_factor
            self.prmtrs['background'] = background
            self.prmtrs['target_size'] = target_size
            self.prmtrs['crop_size'] = crop_size
            self.prmtrs['unknown_weight'] = unknown_weight
            self.prmtrs['multi_weight'] = multi_weight
            self.prmtrs['scale'] = scale
            self.prmtrs['loss'] = loss
            self.prmtrs['optimizer'] = optimizer
            self.prmtrs['metrics'] = metrics
            self.prmtrs['hsymmetry'] = hsymmetry

            self.reset_model()
            self.classes = None

        self.examplesdir = examplesdir

        # placeholder data fields
        # self.images = None
        self.imagesfile = None
        self.y = None

        # dictionary of labels for an experiment
        self.labels = None

        self.trained = False

        self.imagefile_f = None
        self.passedfile_f = None
        self.ntracklets_in_current_file = None

        self.modelfile = None


    def reset_model(self):

        self.trained = False
        self.model = new_model(self.prmtrs)
        self.compile_model()

    def compile_model(self):

        self.model.compile(loss=self.prmtrs['loss'], optimizer=self.prmtrs['optimizer'], metrics=self.prmtrs['metrics'])

    def save(self, modelfile):

        # save model
        self.model.save(modelfile)

        # save classifier params
        with h5py.File(modelfile, 'a') as f:
            f.create_dataset('prmtrs', data=json.dumps(self.prmtrs))
            if self.classes is not None:
                f.create_dataset('classes', (len(self.classes), 1), 'S10', [np.string_(x) for x in self.classes])

    def check_example_dir(self, remove=False):

        imagefiles = glob(self.examplesdir + '/*/*.*')

        for imfile in imagefiles:

            try:
                im = Image.open(imfile)
            except:
                report('W', 'corrupt image ' + imfile)
                if remove:
                    os.remove(imfile)

    def prepare_images(self, images):

        # make 4D if only one image in data set
        if images.ndim == 3:
            images = np.reshape(images, (1,) + images.shape)

        # transform matlab image array into tensor
        images = np.moveaxis(images, [0, 1, 2, 3], [0, 3, 2, 1])

        # change background
        if self.prmtrs['background'] == 'white':
            msk = images.max(axis=3) == 0
            msk = msk[:, :, :, None]
            msk = np.tile(msk, [1, 1, 1, 3])
            images[msk] = 255
        elif self.prmtrs['background'] == 'black':
            msk = images.max(axis=3) == 255
            msk = msk[:, :, :, None]
            msk = np.tile(msk, [1, 1, 1, 3])
            images[msk] = 0

        # crop images
        if self.prmtrs['crop_size'] is not None and images.shape[1] > self.prmtrs['crop_size']:

            a = np.floor((images.shape[1] - self.prmtrs['crop_size'])/2).astype('int')

            images = images[:, a:(a+self.prmtrs['crop_size']), a:(a+self.prmtrs['crop_size']), :]

        # resize images
        if images.shape[1] != self.prmtrs['target_size'] or self.prmtrs['scale'] != 1:
            a0 = self.prmtrs['target_size']
            a1 = int(float(a0) * self.prmtrs['scale'])
            resized = np.zeros([images.shape[0], a1, a1, images.shape[-1]], dtype=np.uint8)
            for i in range(images.shape[0]):
                resized[i] = np.array(Image.fromarray(images[i]).resize((a1, a1)))

            images = resized[:, int((a1 - a0) / 2):int((a1 + a0) / 2), int((a1 - a0) / 2):int((a1 + a0) / 2), :]

        images = images.astype('float32')

        return images

    def predict_images(self, images, model=None, debug=False):

        if model is None:
            model = self.model

        if tf.shape(images.shape)[0] == 0:
            y = []
        else:
            y = model.predict(images)

        return y

    def process_predictions(self, y, debug=False):

        if len(y) == 0:
            return 'Unknown', 0, -1

        frame_nums = np.arange(y.shape[0])

        # non-ant label is only assigned if all images were recognized as such. Otherwise, ignore images with non-ant labels for tracklet classification
        y_index = y.argmax(axis=1)
        y_txt = [self.classes[ix] for ix in y_index]

        y_noant = [lab in self.labels['noant_labels'] for lab in y_txt]
        y_multi = [lab in MULTI_CLASSES for lab in y_txt]
        y_ambig = [lab in self.labels['other_labels'] for lab in y_txt]
        y_ants = [lab in self.labels['ant_labels'] for lab in y_txt]

        # if all frames are non-ant, return the most common non ant label
        if all(y_noant):
            lab = max(y_txt, key=y_txt.count)
            return lab, 0, -1

        # if there are multi labels, return multi
        if (any(y_multi) and not any(y_ants)) or np.mean(y_multi)>0.25:
            y_txt = [l for l in y_txt if l in MULTI_CLASSES]
            lab = max(y_txt, key=y_txt.count)
            return lab, 0, -1

        # if there are no ant labels, return ambig label
        if all(y_ambig) or not any(y_ants):
            lab = max(y_txt, key=y_txt.count)
            return lab, 0, -1

        ant_cols = [lab in self.labels['ant_labels'] for lab in self.classes]
        ant_cols = [i for i, x in enumerate(ant_cols) if x]

        y1 = y[y_ants]
        s = y1[:, ant_cols].sum(axis=0)
        if s.sum() > 0:
            s = s / s.sum()

        lix = s.argmax()

        frame_score = y1[:, ant_cols[lix]]

        # def #1: just the sum of the frame scores for the assigned ID
        score = frame_score.sum()

        # def #2:
        # score = frame_score.sum() / y1[:, ant_cols[lix]]

        score = score.tolist()
        label = self.classes[ant_cols[lix]]

        if self.prmtrs['use_min_conf']:
            if y1[:, ant_cols].max() < self.prmtrs['min_conf']:
                return 'Unknown', 0, -1

            if y1.shape[0] < 5 and y1[:,ant_cols].max() < self.prmtrs['min_conf_short']:
                return 'Unknown', 0, -1

        frame_nums = frame_nums[y_ants]
        best_frame = frame_nums[frame_score.argmax()].item()

        return label, score, best_frame

    def predict_tracklet(self, tracklet, model=None):

        images = self.imagefile_f[tracklet][()]
        images = self.prepare_images(images)

        indexes = np.arange(images.shape[0])
        if self.passedfile_f is not None:
            passed = self.passedfile_f[tracklet][()][0]
            indexes = np.nonzero(passed)[0]
            images = images[indexes]

        y = self.predict_images(images, model=model)
        label, score, best_frame = self.process_predictions(y)

        if best_frame >= 0:
            best_frame = indexes[best_frame] + 1
        else:
            best_frame = best_frame + 1

        return label, score, best_frame

    def prediction_worker(self):

        thread_model = get_thread_model(self.modelfile)

        with thread_model['graph'].as_default():
            with thread_model['session'].as_default():

                while True:
                    tracklet = self.q_tracklets.get()
                    if tracklet is None:
                        break
                    label, score, best_frame = self.predict_tracklet(tracklet, model=thread_model['model'])
                    self.q_predictions.put((tracklet, label, score, best_frame))
                    self.q_tracklets.task_done()
                    printProgressBar(self.ntracklets_in_current_file - self.q_tracklets.qsize(), self.ntracklets_in_current_file, prefix='Progress:', suffix='Complete', length=50)

    def predict_images_file(self, imagefile, outfile=None, usepassed=False, verbose=False):

        m = int(imagefile.rstrip('.mat').split('_')[1])

        # read frame filter file
        passed_file = 'frame_passed_' + imagefile.lstrip('images_')
        self.passedfile_f = None
        if usepassed and isfile(join(self.imagedir, passed_file)):
            self.passedfile_f = h5py.File(join(self.imagedir, passed_file), 'r')

        self.imagefile_f = h5py.File(join(self.imagedir, imagefile), 'r')

        self.ntracklets_in_current_file = len(self.imagefile_f)

        print('         ...' + str(self.ntracklets_in_current_file) + ' tracklets to classify in movie' )

        if verbose:
            printProgressBar(0, self.ntracklets_in_current_file, prefix='Progress:', suffix='Complete', length=50)

        for tracklet in self.imagefile_f.keys():

            self.q_tracklets.put(tracklet)

        self.q_tracklets.join()

        self.imagefile_f.close()
        self.imagefile_f = None

        if self.passedfile_f is not None:
            self.passedfile_f.close()
            self.passedfile_f = None

        if outfile is None:
            outfile = os.path.join(self.outdir, 'autoids_' + str(m) + '.csv')

        with open(outfile, "w") as output:
            writer = csv.writer(output, lineterminator='\n')
            writer.writerow(['tracklet', 'label', 'score', 'best_frame'])
            while not self.q_predictions.empty():
                p = self.q_predictions.get()
                writer.writerow(p)
                self.q_predictions.task_done()

    def predict_experiment(self, expdir, session=None, movlist='all', outdir=None, usepassed=False, verbose=None, nw=1):

        if type(expdir) == axExperiment:
            if session is not None and not expdir.session == session:
                ex = axExperiment(expdir.expdir, session)
            else:
                ex = expdir
                expdir = ex.expdir
        else:
            ex = axExperiment(expdir, session)

        self.labels = ex.get_labels()
        self.imagedir = ex.imagedir
        self.outdir = outdir if outdir is not None else ex.labelsdir

        mkdir(self.outdir)

        self.imagefiles = [f for f in listdir(self.imagedir) if isfile(join(self.imagedir, f))]
        self.imagefiles = [f for f in self.imagefiles if 'images' in f]
        movieindex = [int(x.rstrip('.mat').split('_')[1]) for x in self.imagefiles]
        self.imagefiles = [x for _, x in sorted(zip(movieindex, self.imagefiles))]
        movieindex = sorted(movieindex)
        if movlist is not None and not movlist == 'all':
            if isinstance(movlist, str):
                movlist = [int(m) for m in movlist.split(',')]
            self.imagefiles = [f for f in self.imagefiles if movieindex[self.imagefiles.index(f)] in movlist]

        if verbose is None:
            verbose = len(self.imagefiles) == 1

        self.q_tracklets = queue.Queue()
        self.q_predictions = queue.Queue()

        self.prediction_threads = []

        for i in range(nw):
            t = threading.Thread(target=self.prediction_worker)
            t.start()
            self.prediction_threads.append(t)

        for f in self.imagefiles:
            m = int(f.rstrip('.mat').split('_')[1])
            report('I', 'Classifying tracklets of movie ' + str(m))
            self.predict_images_file(f, usepassed=usepassed, verbose=verbose)

        report('I', 'Stopping workers')
        for i in range(nw):
            self.q_tracklets.put(None)

        for t in self.prediction_threads:
            t.join()

        report('G', 'Done!')

    def validate(self, examplesdir, force=False, augment=False):


        #
        if not self.trained:
            print('-E- Please train classifier first')

        # how many classes in example dir?
        classes = classes_from_examplesdir(examplesdir)

        if self.classes is not None and (classes != self.classes) and not force:
            print('-E- Class list in example dir does not match classifier')
            return

        prepfun = None if self.prmtrs['scale'] == 1 else scale_and_crop

        if not augment:
            DG = image.ImageDataGenerator(
                                      width_shift_range=0,
                                      height_shift_range=0,
                                      shear_range=0,
                                      rotation_range=0,
                                      zoom_range=0,
                                      channel_shift_range=0,
                                      horizontal_flip=self.prmtrs['hsymmetry'],
                                      vertical_flip=True)
        else:

            DG = image.ImageDataGenerator(
                width_shift_range=10,
                height_shift_range=10,
                shear_range=5,
                rotation_range=15,
                zoom_range=0.1,
                brightness_range=(0.9, 1.1),
                channel_shift_range=0,
                horizontal_flip=self.prmtrs['hsymmetry'],
                vertical_flip=True)

        FL = DG.flow_from_directory(examplesdir,
                                    target_size=(self.prmtrs['target_size'], self.prmtrs['target_size']),
                                    batch_size=1,
                                    classes=classes,
                                    shuffle=False)

        FL.reset()
        y_pred = self.model.predict_generator(FL, FL.n, workers=6)

        # Confusion Matrix and Classification Report
        y_pred = np.argmax(y_pred, axis=-1)
        y = FL.classes[FL.index_array]
        correct_labels = [self.classes[x] for x in y]
        predict_labels = [self.classes[x] for x in y_pred]

        a = [len(c) for c in classes]
        ordered_classes = [x for _, x in sorted(zip(a, classes))]

        cm = confusion_matrix(correct_labels,
                              predict_labels,
                              labels=ordered_classes)
        cmdf = pd.DataFrame(cm,
                            columns=ordered_classes,
                            index=ordered_classes)

        report = classification_report(y, y_pred, target_names=classes)

        error = 1 - np.mean(y == y_pred)

        print('Confusion Matrix')
        print(cmdf)
        print('Classification Report')
        print(report)

        return error

    def train(self, examplesdir, ne=5, verbose=1, patience=10, min_delta=0.002, aug_options=''):

        if aug_options is None or aug_options == ' ' or aug_options == '':
            aug_options = {}
        else:
            aug_options = {x.split('=')[0]: x.split('=')[1] for x in aug_options.split(',') if '=' in x}
            for k, v in aug_options.items():
                if v.isnumeric():
                    aug_options[k] = int(v)

        if isinstance(examplesdir, list):
            rm_after = True
            examplesdir = tmp_examplesdir(examplesdir)
        else:
            rm_after = False

        # how many classes in example dir?
        classes = classes_from_examplesdir(examplesdir)

        if self.trained and (classes != self.classes):

            print('-E- Class list in example dir does not match classifier. Use --scratch to train a new model')
            return

        # create data generators
        prepfun = None if self.prmtrs['scale'] == 1 else scale_and_crop

        DG = image.ImageDataGenerator(
                                    width_shift_range=aug_options.get('width_shift_range', 10),
                                    height_shift_range=aug_options.get('height_shift_range', 10),
                                    shear_range=aug_options.get('shear_range', 5),
                                    rotation_range=aug_options.get('rotation_range', 15),
                                    zoom_range=aug_options.get('zoom_range', 0.1),
                                    brightness_range=(0.9, 1.1),
                                    channel_shift_range=0,
                                    horizontal_flip=self.prmtrs['hsymmetry'],
                                    vertical_flip=True)

        FL = DG.flow_from_directory(examplesdir,
                                    classes=classes,
                                    class_mode='categorical',
                                    target_size=(self.prmtrs['target_size'], self.prmtrs['target_size']),
                                    batch_size=32,
                                    subset='training',
                                    shuffle=True)

        early_stopping = EarlyStopping(monitor='loss', patience=patience, min_delta=min_delta)
        reduce_lr = ReduceLROnPlateau(monitor='loss', factor=0.5, patience=5, min_lr=0.0001)

        cw = class_weight.compute_class_weight('balanced', np.unique(FL.classes), FL.classes)

        if 'Unknown' in classes:
            cw[FL.class_indices['Unknown']] = self.prmtrs['unknown_weight'] * cw[FL.class_indices['Unknown']]

        if 'MultiAnt' in classes:
            cw[FL.class_indices['MultiAnt']] = self.prmtrs['multi_weight'] * cw[FL.class_indices['MultiAnt']]

        if 'Multi' in classes:
            cw[FL.class_indices['Multi']] = self.prmtrs['multi_weight'] * cw[FL.class_indices['Multi']]

        # compile model
        self.compile_model()

        # train model
        self.model.fit_generator(FL,
                                 steps_per_epoch=1000,
                                 epochs=ne,
                                 class_weight=cw,
                                 callbacks=[early_stopping, reduce_lr],
                                 verbose=verbose)

        self.classes = list(FL.class_indices.keys())
        self.trained = True

        # cleanup
        if rm_after:
            shutil.rmtree(examplesdir)


def crop_image():

    pass


def scale_and_crop(im, scale):

    a0 = im.shape[0]
    a1 = int(float(a0) * scale)

    if a1 % 2 > 0:
        a1 = a1 - 1

    im = Image.fromarray(im.astype('uint8'))
    im = im.resize((a1, a1))
    im = np.array(im)

    im = im[int((a1-a0)/2):int((a1+a0)/2), int((a1-a0)/2):int((a1+a0)/2), :]

    return im


def tmp_examplesdir(examplesdirs, n=None):

    print('-I- making joined example dir')

    edir = mkdtemp()

    for ed in examplesdirs:

        if isdir(ed):

            classes = classes_from_examplesdir(ed)

            for c in classes:

                dst = join(edir, c)
                mkdir(dst)

                for f in glob(join(ed, c) + '/*.png'):

                    shutil.copy(f, dst)

    return edir
