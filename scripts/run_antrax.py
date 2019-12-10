#!/usr/bin/env python3

from clize import run, Parameter, parser
from sigtools.wrappers import decorator
from os.path import isfile, isdir, join, splitext

from time import sleep

from antrax import axExperiment
from antrax.hpc import antrax_hpc_job
from antrax.utils import *

########################### AUX functions #########################

@parser.value_converter
def parse_hpc_options(s):

    if s is None or s == '':
        return {}

    opts = {x.split('=')[0]: x.split('=')[1] for x in s.split(',') if '=' in x}
    for k, v in opts.items():
        if v.isnumeric():
            opts[k] = int(v)

    return opts


@parser.value_converter
def parse_movlist(movlist):

    movlist = parse_movlist_str(movlist)

    return movlist

@parser.value_converter
def parse_explist(exparg):

    exps = []

    if isdir(exparg) and is_expdir(exparg):
        exps.append(axExperiment(exparg))
    elif isfile(exparg):
        with open(exparg) as f:
            for line in f:
                line = line.rstrip()
                if line.isspace() or len(line) == 0 or line[0].isspace():
                    continue
                if line[0] != '#':
                    lineparts = line.split(' ')
                    exps.append(axExperiment(lineparts[0]))
    elif isdir(exparg):
        explist = find_expdirs(exparg)
        exps = [axExperiment(e) for e in explist if is_expdir(e)]
    else:
        print('Something wrong with explist argument')
        exps = []

    return exps


########################### Run functions ##########################


def configure():
    """Launch antrax configuration app"""
    eng = start_matlab()
    a = eng.antrax()

    while eng.isvalid(a, ):
        sleep(0.25)


def track(explist: parse_explist, *, movlist: parse_movlist=None, nw=2, hpc=False, hpc_options: parse_hpc_options=' ',
          session=None):

    if hpc:
        for e in explist:
            hpc_options['classifier'] = classifier
            hpc_options['movlist'] = movlist
            antrax_hpc_job(e, 'classify', opts=hpc_options)
    else:

        Q = MatlabQueue(nw=nw)

        for e in explist:
            for m in movlist:
                Q.add_track_task(e, m)

        # wait for tasks to complete
        Q.join()

        # run cross movie link
        for e in explist:
            Q.add_task('link_across_movies', [e.expdir])

        # close
        Q.stop_workers()

def train(classifier, *, scratch=False, ne=5, unknown_weight=50, verbose=1, target_size=None, nw=0, scale=None):

    if target_size is not None:
        target_size = int(target_size)

    if scale is not None:
        scale = float(scale)


def classify(explist: parse_explist, *, classifier, movlist: parse_movlist=None, hpc=False, hpc_options: parse_hpc_options=' ',
             nw=0, session=None, usepassed=False, dont_use_min_conf=False, consv_factor=None):

    if not hpc:
        from antrax.classifier import axClassifier
        C = axClassifier.load(classifier)

    for e in explist:
        if hpc:
            hpc_options['classifier'] = classifier
            hpc_options['movlist'] = movlist
            antrax_hpc_job(e, 'classify', opts=hpc_options)
        else:
            C.predict_experiment(e, movlist=movlist)


def solve(explist):

    pass


def dlc(explist: parse_explist, *, cfg, movlist: parse_movlist=None, session=None, hpc=False, hpc_options: parse_hpc_options=' '):
    """Run DeepLabCut on antrax experiment

     :param explist: path to experiment folder, path to file with experiment folders, path to a folder containing several experiments
     :param session: run on specific session
     :param cfg: Full path to DLC project config file
     :param movlist: List of video indices to run (default is all)
     :param hpc: Run using slurm worload maneger (default is False)
     :param hpc_options: comma separated list of options for hpc run
     """

    for e in explist:
        if hpc:
            hpc_options['cfg'] = cfg
            hpc_options['movlist'] = movlist
            antrax_hpc_job(e, 'dlc', opts=hpc_options)
        else:
            from antrax.dlc import dlc4antrax
            print('Running DeepLabCut on experiment ' + e.expname)
            dlc4antrax(e, dlccfg=cfg, movlist=movlist)


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
