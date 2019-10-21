#!/usr/bin/env python3

from clize import run
from sigtools.wrappers import decorator
from os.path import isfile, isdir, join, splitext

from antrax import *

@decorator
def parse_movlist(wrapped, *args, **kwargs):

    if 'movlist' in kwargs.keys():

        kwargs['movlist'] = parse_movlist_str(kwargs['movlist'])

    return wrapped(*args, **kwargs)


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

    exps = [axExperiment(e) for e in explist]
    return wrapped(*args, exps=exps, **kwargs)


def configure():
    """Launch antrax configuration app"""

    print('')
    print('Launching antrax configuration app')
    print('')

@expand_explist
def track(explist, exps=None, movlist='all'):
    """Track experiment (or list of experiments) on local machine

    :param expdirs: A message to store alongside the commit
    """
    print('')
    print('Tracking experiments:')
    for e in exps:
        print(e)


def train(classdir, *, scratch=False, ne=5, unknown_weight=50, verbose=1, target_size=None, nw=0, scale=None):
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
    if target_size is not None:
        target_size = int(target_size)

    if scale is not None:
        scale = float(scale)

    C = axClassifier(classdir, nw)

    C.train_model(from_scratch=scratch,
                  ne=ne,
                  unknown_weight=unknown_weight,
                  verbose=verbose,
                  scale=scale,
                  target_size=target_size)

    C.save_model()
    C.validate_model()


@expand_explist
@parse_movlist
def classify(explist, *, classdir, nw=0, session=None, movlist='all', usepassed=False, dont_use_min_conf=False, consv_factor=None):

    C = axClassifier(classdir, nw, consv_factor=consv_factor, use_min_conf=(not dont_use_min_conf))

    C.predict_experiment(explist,
                         session=session,
                         movlist=movlist,
                         usepassed=usepassed)

@expand_explist
@parse_movlist
def solve(explist):

    pass

@expand_explist
@parse_movlist
def hpc(explist):

    pass


def track_hpc(explist):

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
