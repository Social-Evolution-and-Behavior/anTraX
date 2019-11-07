from os import listdir
from os.path import isfile, join
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import backend as K
from tensorflow.keras.preprocessing import image
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
from tensorflow.keras.layers import Dense, Dropout, Activation, Flatten
import h5py
import numpy as np
import os
import csv
import shutil
from tempfile import mkdtemp

from PIL import Image
from glob import glob
from sklearn.utils import class_weight
from sklearn.metrics import confusion_matrix, classification_report
from datetime import datetime
import pandas as pd

from .experiment import *
from .utils import *
from .models import new_model

AMBIG_CLASSES = ['Unknown', '??', 'MultiAnt']
NONANT_CLASSES = ['NoAnt', 'FOOD', 'Larva']


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
        if c.classes is not None:
            c.trained = True

        return c

    def __init__(self,
                 name,
                 nclasses,
                 modeltype='small',
                 loss='categorical_crossentropy',
                 optimizer='adam',
                 metrics=['accuracy'],
                 background='white',
                 consv_factor=0.5,
                 use_min_conf=True,
                 examplesdir=None,
                 target_size=64,
                 scale=1,
                 loaded=False,
                 model=None,
                 prmtrs=None,
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
            self.prmtrs['use_min_conf'] = use_min_conf
            self.prmtrs['consv_factor'] = consv_factor
            self.prmtrs['min_conf'] = 1 - 0.2 * consv_factor
            self.prmtrs['min_conf_short'] = 1 - 0.02 * consv_factor
            self.prmtrs['background'] = background
            self.prmtrs['target_size'] = target_size
            self.prmtrs['scale'] = scale
            self.prmtrs['loss'] = loss
            self.prmtrs['optimizer'] = optimizer
            self.prmtrs['metrics'] = metrics

            self.reset_model()
            self.classes = None

        self.examplesdir = examplesdir

        # placeholder data fields
        self.images = None
        self.imagesfile = None
        self.y = None

        # dictionary of labels for an experiment
        self.labels = None

        self.trained = False

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
            f.create_dataset('classes', (len(self.classes), 1), 'S10', [np.string_(x) for x in self.classes])

    def prepare_images(self):

        # make 4D if only one image in data set
        if self.images.ndim == 3:
            self.images = np.reshape(self.images, (1,) + self.images.shape)

        # transform matlab image array into tensor
        self.images = np.moveaxis(self.images, [0, 1, 2, 3], [0, 3, 2, 1])

        # change background
        if self.prmtrs['background'] == 'white':
            msk = self.images.max(axis=3) == 0
            msk = msk[:, :, :, None]
            msk = np.tile(msk, [1, 1, 1, 3])
            self.images[msk] = 255
        elif self.prmtrs['background'] == 'black':
            msk = self.images.max(axis=3) == 255
            msk = msk[:, :, :, None]
            msk = np.tile(msk, [1, 1, 1, 3])
            self.images[msk] = 0

        # resize images
        if self.images.shape[1] != self.prmtrs['target_size'] or self.prmtrs['scale'] != 1:
            a0 = self.prmtrs['target']
            a1 = int(float(a0) * self.prmtrs['scale'])
            resized = np.zeros([self.images.shape[0], a1, a1, self.images.shape[-1]], dtype=np.uint8)
            for i in range(self.images.shape[0]):
                resized[i] = np.array(Image.fromarray(self.images[i]).resize((a1, a1)))

            self.images = resized[:, int((a1 - a0) / 2):int((a1 + a0) / 2), int((a1 - a0) / 2):int((a1 + a0) / 2), :]

    def predict_images(self):

        if self.images.size == 0:
            return 'Unknown', 0, -1

        y = self.model.predict(self.images)
        self.y = y

        frame_nums = np.arange(y.shape[0])

        # non-ant label is only assigned if all images were recognized as such. Otherwise, ignore images with non-ant labels for tracklet classification
        y_index = y.argmax(axis=1)
        y_txt = [self.classes[ix] for ix in y_index]
        y_noant = [lab in self.labels['nonant_labels'] for lab in y_txt]
        y_ambig = [lab in self.labels['other_labels'] for lab in y_txt]
        y_ants = [lab in self.labels['ant_labels'] for lab in y_txt]

        # if all frames are non-ant, return the most common non ant label
        if all(y_noant):
            lab = max(y_txt, key=y_txt.count)
            return lab, 0, -1

        if all(y_ambig):
            lab = max(y_txt, key=y_txt.count)
            return lab, 0, -1

        if not any(y_ants):
            lab = 'Unknown'
            return lab, 0, -1

        ant_cols = [lab in self.labels['ant_labels'] for lab in self.classes]
        ant_cols = [i for i, x in enumerate(ant_cols) if x]

        y1 = y[y_ants]
        s = y1[:, ant_cols].sum(axis=0)
        if s.sum() > 0:
            s = s / s.sum()

        lix = s.argmax()

        frame_score = y1[:, ant_cols[lix]]
        score = frame_score.sum()

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

    def predict_images_file(self, imagefile, outfile=None, usepassed=False):

        scores = []
        labels = []
        names = []
        best_frames = []
        comments = []

        m = int(imagefile.rstrip('.mat').split('_')[1])

        # read frame filter file
        passed_file = 'frame_passed_' + imagefile.lstrip('images_')
        pf = None
        if isfile(join(self.imagedir, passed_file)):
            pf = h5py.File(join(self.imagedir, passed_file), 'r')

        f = h5py.File(join(self.imagedir, imagefile), 'r')

        for tracklet in f.keys():

            self.images = f[tracklet][()]

            # preprocess the image and prepare it for classification
            self.prepare_images()

            # filter frames
            indexes = np.arange(self.images.shape[0])
            if usepassed and pf is not None:
                passed = pf[tracklet][()][0]
                indexes = np.nonzero(passed)[0]
                self.images = self.images[indexes]

            # predict
            label, score, best_frame = self.predict_images()
            scores += [score]
            labels += [label]
            comments += ['']
            if best_frame >= 0:
                best_frames += [indexes[best_frame] + 1]
            else:
                best_frames += [best_frame + 1]

            names += [tracklet]

        if outfile is None:
            outfile = os.path.join(self.outdir, 'autoids_' + str(m) + '.csv')

        with open(outfile, "w") as output:
            writer = csv.writer(output, lineterminator='\n')
            writer.writerow(['tracklet', 'label', 'score', 'best_frame'])
            for (n, l, p, b) in zip(names, labels, scores, best_frames):
                writer.writerow([n, l, p, b])

    def predict_experiment(self, expdir, session=None, movlist='all', outdir=None, usepassed=False):

        ex = axExperiment(expdir, session)

        self.labels = ex.get_labels()
        self.imagedir = ex.imagedir
        self.outdir = outdir if outdir is not None else ex.labelsdir

        self.imagefiles = [f for f in listdir(self.imagedir) if isfile(join(self.imagedir, f))]
        self.imagefiles = [f for f in self.imagefiles if 'images' in f]
        movieindex = [int(x.rstrip('.mat').split('_')[1]) for x in self.imagefiles]
        self.imagefiles = [x for _, x in sorted(zip(movieindex, self.imagefiles))]
        movieindex = sorted(movieindex)
        if not movlist == 'all':
            if isinstance(movlist, str):
                movlist = [int(m) for m in movlist.split(',')]
            self.imagefiles = [f for f in self.imagefiles if movieindex[self.imagefiles.index(f)] in movlist]

        for f in self.imagefiles:
            m = int(f.rstrip('.mat').split('_')[1])
            ts = datetime.now().strftime('%d/%m/%y %H:%M:%S')
            print(ts + ' -I- Classifying tracklets of movie ' + str(m))
            self.predict_images_file(f, usepassed=usepassed)

        ts = datetime.now().strftime('%d/%m/%y %H:%M:%S')
        print(ts + ' -G- Done!')

    def validate(self, examplesdir):


        #
        if not self.trained:
            print('-E- Please train classifier first')

        # how many classes in example dir?
        classes = classes_from_examplesdir(examplesdir)

        if self.classes is not None and (classes != self.classes):
            print('-E- Class list in example dir does not match classifier')
            return

        prepfun = None if self.prmtrs['scale'] == 1 else scale_and_crop

        DG = image.ImageDataGenerator(
                                      width_shift_range=0,
                                      height_shift_range=0,
                                      shear_range=0,
                                      rotation_range=0,
                                      zoom_range=0,
                                      channel_shift_range=0,
                                      horizontal_flip=True,
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

        # c1 = [c for c in self.classes if c in self.labels['ant_labels']]
        # c2 = [c for c in self.classes if c in self.labels['nonant_labels']]
        # c3 = [c for c in self.classes if c in self.labels['other_labels']]

        # ordered_classes = c1 + c2 + c3

        cm = confusion_matrix(correct_labels,
                              predict_labels,
                              labels=ordered_classes)
        cmdf = pd.DataFrame(cm,
                            columns=ordered_classes,
                            index=ordered_classes)

        #cmdf.to_csv(os.path.join(self.modeldir, "conf_mat.csv"))

        report = classification_report(y, y_pred, target_names=classes)

        error = 1 - np.mean(y == y_pred)

        print('Confusion Matrix')
        print(cmdf)
        print('Classification Report')
        print(report)

        #with open(os.path.join(self.modeldir, "report.txt"), 'w') as f:
        #    f.write("%s" % report)

        # np.savetxt(os.path.join(self.modeldir, "conf_mat.txt"),cm, fmt='%5d',delimiter=" ")

        # filenames = test_generator.filenames

        # wrong_filenames = [fn for i,fn in enumerate(filenames) if y_pred[i]==y[i]]

        # with open(os.path.join(self.modeldir, "wrong.txt"),'w') as f:
        #     for item in wrong_filenames:
        #         f.write("%s\n" % item)

        # results = pd.DataFrame({"Filename": filenames,
        #                         "Class":[self.classes[k] for k in y],
        #                         "Prediction":[self.classes[k] for k in y_pred]})

        # results.to_csv(os.path.join(self.modeldir, "results.csv"), index=False)

        #fig = plt.figure()
        #plt.matshow(cm)
        #plt.title('Confusion matrix')
        #plt.colorbar()
        #plt.ylabel('True Label')
        #plt.xlabel('Predicated Label')
        #plt.savefig(os.path.join(self.modeldir, "conf_matrix.jpg"))



        # score = self.model.evaluate_generator(FL, steps=5000)
        # print('validation score  is ' + str(score))

        return error

    def train(self, examplesdir, from_scratch=False, ne=5, unknown_weight=20, multi_weight=0.5, verbose=1):

        if isinstance(examplesdir, list):
            rm_after = True
            examplesdir = tmp_examplesdir(examplesdir)
        else:
            rm_after = False

        # how many classes in example dir?
        classes = classes_from_examplesdir(examplesdir)

        if self.trained and (classes != self.classes):

            print('-E- Class list in example dir does not match classifier. Use --from-scratch to train a new model')
            return

        if from_scratch:
            print('User asked, starting training from scratch')
            self.reset_model()

        # create data generators
        prepfun = None if self.prmtrs['scale'] == 1 else scale_and_crop

        DG = image.ImageDataGenerator(
                                    width_shift_range=10,
                                    height_shift_range=10,
                                    shear_range=5,
                                    rotation_range=10,
                                    zoom_range=0.1,
                                    brightness_range=(0.9, 1.1),
                                    channel_shift_range=0,
                                    horizontal_flip=True,
                                    vertical_flip=True)

        FL = DG.flow_from_directory(examplesdir,
                                    classes=classes,
                                    class_mode='categorical',
                                    target_size=(self.prmtrs['target_size'], self.prmtrs['target_size']),
                                    batch_size=32,
                                    subset='training',
                                    shuffle=True)

        early_stopping = EarlyStopping(monitor='loss', patience=10, min_delta=0.002)
        reduce_lr = ReduceLROnPlateau(monitor='loss', factor=0.5, patience=5, min_lr=0.0001)

        cw = class_weight.compute_class_weight('balanced', np.unique(FL.classes), FL.classes)

        if 'Unknown' in classes:
            cw[FL.class_indices['Unknown']] = unknown_weight * cw[FL.class_indices['Unknown']]

        if 'MultiAnt' in classes:
            cw[FL.class_indices['MultiAnt']] = multi_weight * cw[FL.class_indices['MultiAnt']]

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


def classes_from_examplesdir(examplesdir):

    # how many classes in example dir?
    classes = sorted([x.split('/')[-1] for x in glob(examplesdir+'/*')])

    # exclude empty subdirectories
    classes = [x for x in classes if listdir(join(examplesdir, x))]

    return classes


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
