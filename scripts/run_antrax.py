#!/usr/bin/env python3

from clize import run, Parameter
from sigtools.wrappers import decorator
from os.path import isfile, isdir, join, splitext

from time import sleep

from antrax import *

@decorator
def parse_movlist(wrapped, *args, movlist=None, **kwargs):

    movlist = parse_movlist_str(movlist)

    return wrapped(*args, movlist=movlist, **kwargs)


@decorator
def expand_explist(wrapped, *args, **kwargs):
    """A decorator to expand argument to experiment list

    :param wrapped: The decorated function
    :param exparg: The explist argument to expand. Can be a text file with expdir list, a root directory, or just an expdir
    """

    exparg = args[0]

    if isdir(exparg) and is_expdir(exparg):
        explist = [exparg]
    elif isfile(exparg):
        explist = []
        with open(exparg) as f:
            for line in f:
                line = line.rstrip()
                if line.isspace() or len(line) == 0 or line[0].isspace():
                    continue
                if line[0] != '#':
                    lineparts = line.split(' ')
                    explist.append(lineparts[0])
    else:
        explist = find_expdirs(exparg)

    return wrapped(explist, *args[1:], **kwargs)


def configure():
    """Launch antrax configuration app"""

    try:
        import matlab.engine
    except:
        print('')
        print('Please install MATLAB and MATLAB engine for python')
        print('')
        return

    # Start matlab engine
    eng = matlab.engine.start_matlab()

    # Run the antrax app
    a = eng.antrax()

    while eng.isvalid(a, ):
        sleep(0.25)


@expand_explist
@parse_movlist
def track(explist, session=None, movlist='all', nw=0):
    """Track experiment (or list of experiments) on local machine

    :param expdirs:
    :param session:
    :param movlist:
    :param nw:
    """
    print('')
    print('Tracking experiments:')
    for e in explist:
        ex = axExperiment(e, session)
        print(ex.expname)

    #


def train(classdir, *, modeltype='small', scratch=False, ne=5, unknown_weight=50, verbose=1, nw=0):
    """Train a classifier on local machine

    :param classdir: The classifier directory to train
    :param scratch: Start training from scratch
    :param ne: Number of training epochs to run
    :param nw: Number of processes to use
    :param scale:
    :param target_size:
    :param unknown_weight:
    :param verbose:
    """

    if isfile(classfile):

        c = axClassifier.load(classfile)

    else:

        c = axClassifier()

    c.train(from_scratch=scratch,
                  ne=ne,
                  unknown_weight=unknown_weight,
                  verbose=verbose)

    c.save(join(classdir, 'model.h5'))
    c.validate(join(classdir, 'examples'))


@expand_explist
@parse_movlist
def classify(explist, *, classdir, nw=0, session=None, expanded_explist=None, movlist='all', usepassed=False, dont_use_min_conf=False, consv_factor=None):

    C = axClassifier(classdir, nw, consv_factor=consv_factor, use_min_conf=(not dont_use_min_conf))

    C.predict_experiment(explist,
                         session=session,
                         movlist=movlist,
                         usepassed=usepassed)

@expand_explist
@parse_movlist
def solve(explist, session=None):

    pass

@expand_explist
@parse_movlist
def hpc(explist, session=None, expanded_explist=None):

    pass


if __name__ == '__main__':

    function_list = {
        'configure': configure,
        'track': track,
        'train': train,
        'classify': classify,
        'solve': solve,
        'hpc': hpc
    }

    run(function_list)
