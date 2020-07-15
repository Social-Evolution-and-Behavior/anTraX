
from clize import run, Parameter, parser
import antrax as ax
import tensorflow as tf
from os.path import isfile, isdir, join, splitext, dirname
from os import makedirs
import tempfile
from glob import glob
from random import shuffle
from shutil import copyfile


def classifier_test_fun(classdir, *, n=1000, target_size=64, nids=None, name=None, ne=100, logfile=None):


    classfile = join(classdir, name + '.h5')
    examplesdir = join(classdir, 'examples')
    classdirs = glob(examplesdir + '/*')
    nclasses = len(classdirs)

    nc = round(n/nclasses)

    with tempfile.TemporaryDirectory() as d:

        # list examples
        tdir = join(d, 't')
        vdir = join(d, 'v')

        for c in classdirs:

            examples = glob(c + '/*.*')
            shuffle(examples)
            examples = examples[:nc]
            ncreal = len(examples)
            tset = examples[:round(0.8*ncreal)]
            vset = examples[round(0.8*ncreal):]

            tset_new = [x.replace(classdir, d).replace('examples', 't') for x in tset]
            vset_new = [x.replace(classdir, d).replace('examples', 'v') for x in vset]

            ax.report('I', c + ' ' + str(len(tset_new)))
            ax.report('I', c + ' ' + str(len(vset_new)))

            for x, y in zip(tset, tset_new):
                makedirs(dirname(y), exist_ok=True)
                copyfile(x, y)

            for x, y in zip(vset, vset_new):
                makedirs(dirname(y), exist_ok=True)
                copyfile(x, y)

        tnclasses = len(glob(tdir + '/*'))
        vnclasses = len(glob(vdir + '/*'))

        print(str(vnclasses))
        print(str(tnclasses))

        if tnclasses != nclasses:
            ax.report('E', 'some classes dont have examples')
            ve = -1
        else:

            # train a classifier
            c = ax.axClassifier(name, nclasses=nclasses, target_size=target_size, hsymmetry=True,
                     unknown_weight=20, multi_weight=0.1, modeltype='small')

            c.train(tdir, ne=ne, patience=3, min_delta=0.01)

            # validate
            ve = c.validate(vdir, force=True, augment=True)

            # copy classifier
            c.save(classfile)

        # log the validation error
        if logfile is not None:
            with open(logfile, 'a') as f:
                f.write('\t'.join([name, str(n), str(target_size), str(nids), str(ve)]) + '\n')


if __name__ == '__main__':

    run(classifier_test_fun)
