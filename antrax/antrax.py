#!/usr/bin/env python3

from clize import run
from sigtools.wrappers import decorator
from os.path import isfile, isdir, join, splitext

from . import *
from .utilshpc import *


########################### AUX functions #########################

def parse_movlist(movlist):

    movlist = parse_movlist_str(movlist)

    return movlist


def parse_explist(exparg, session=None):

    exps = []

    if isdir(exparg) and is_expdir(exparg):
        exps.append(axExperiment(exparg, session))
    elif isfile(exparg):
        with open(exparg) as f:
            for line in f:
                line = line.rstrip()
                if line.isspace() or len(line) == 0 or line[0].isspace():
                    continue
                if line[0] != '#':
                    lineparts = line.split(' ')
                    exps.append(axExperiment(lineparts[0],session))
    elif isdir(exparg):
        explist = find_expdirs(exparg)
        exps = [axExperiment(e, session) for e in explist if is_expdir(e)]
    else:
        print('Something wrong with explist argument')
        exps = []

    return exps


########################### Run functions ##########################

def configure():
    """Launch antrax configuration app"""

    print('')
    print('Launching antrax configuration app')
    print('')


def track(explist, movlist='all'):
    """Track experiment (or list of experiments) on local machine

    :param expdirs: A message to store alongside the commit
    """

    exps = parse_explist(explist)
    movlist = parse_movlist(movlist)

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


def classify(explist, *, classdir, nw=0, session=None, movlist='all', usepassed=False, dont_use_min_conf=False, consv_factor=None):

    C = axClassifier(classdir, nw, consv_factor=consv_factor, use_min_conf=(not dont_use_min_conf))

    C.predict_experiment(explist,
                         session=session,
                         movlist=movlist,
                         usepassed=usepassed)


def solve(explist):

    pass


def dlc(explist, *, dlccfg, movlist=None, session=None, hpc=False, **kwargs):
    """Run DeepLabCut on antrax experiment

     :param explist: path to experiment folder, path to file with experiment folders, path to a folder containing several experiments
     :param dlccfg: Full path to DLC project config file
     :param movlist: List of video indices to run (default is all)
     :param hpc: Run using slurm worload maneger (default is False)
     """
    from .dlc import dlc4antrax

    exps = parse_explist(explist, session)
    movlist = parse_movlist(movlist)

    for e in exps:
        if not hpc:
            print('Running DeepLabCut on experiment ' + e.expname)
            dlc4antrax(e, dlccfg=dlccfg, movlist=movlist)
        else:
            clear_tracking_data(e, 'dlc', **kwargs)
            prepare_antrax_job(e, 'dlc', taskarray=movlist, dlccfg=dlccfg, **kwargs)


if __name__ == '__main__':

    function_list = {
        'configure': configure,
        'track': track,
        'train': train,
        'classify': classify,
        'solve': solve,
        'dlc': dlc
    }

    run(function_list)
