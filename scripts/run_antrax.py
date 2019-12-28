#!/usr/bin/env python3

from clize import run, Parameter, parser
from sigtools.wrappers import decorator
from os.path import isfile, isdir, join, splitext

from time import sleep
from imageio import imread
from antrax import *
from antrax.matlab import *
from antrax.hpc import antrax_hpc_job
from antrax.utils import *

########################### AUX functions #########################

@parser.value_converter
def parse_hpc_options(s):

    if s is None or s == ' ':
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


def configure(expdir):
    """Launch antrax configuration app"""

    launch_antrax_app(expdir)


def validate(expdir):
    """Launch antrax configuration app"""

    launch_validate_classifications_app(expdir)


def track(explist: parse_explist, *, movlist: parse_movlist=None, mcr=False, classifier=None, onlystitch=False, nw=2, hpc=False, hpc_options: parse_hpc_options={},
          session=None):

    if hpc:
        for e in explist:
            hpc_options['classifier'] = classifier
            hpc_options['movlist'] = movlist
            antrax_hpc_job(e, 'track', opts=hpc_options)
    else:

        Q = MatlabQueue(nw=nw, mcr=mcr)

        if not onlystitch:
            for e in explist:
                movlist1 = e.movlist if movlist is None else movlist
                for m in movlist1:
                    Q.put(('track_single_movie', e, m))

            # wait for tasks to complete
            Q.join()

        # run cross movie link
        for e in explist:
            Q.put(('link_across_movies', e))

        # close
        Q.stop_workers()


def solve(explist: parse_explist, *, glist: parse_movlist=None, mcr=False, nw=2, hpc=False, hpc_options: parse_hpc_options=' ',
          session=None):

    if hpc:
        for e in explist:
            hpc_options['classifier'] = classifier
            hpc_options['movlist'] = glist
            antrax_hpc_job(e, 'classify', opts=hpc_options)
    else:

        Q = MatlabQueue(nw=nw, mcr=mcr)

        for e in explist:
            for g in glist:
                Q.put(('solve_single_graph', e, g))

        # wait for tasks to complete
        Q.join()

        # close
        Q.stop_workers()


def train(classdir,  *, name='classifier', scratch=False, ne=5, unknown_weight=50, verbose=1, target_size=None):

    if target_size is not None:
        target_size = int(target_size)

    classfile = join(classdir, name + '.h5')
    examplesdir = join(classdir, 'examples')

    if isfile(classfile):
        c = axClassifier.load(classfile)
    else:
        n = len(glob(examplesdir + '/*'))
        if target_size is None:
            f = glob(examplesdir + '/*/*.png')[0]
            target_size = max(imread(f).shape)

        c = axClassifier(name, nclasses=n, target_size=target_size)

    c.train(examplesdir, from_scratch=scratch, ne=ne)
    c.save(classfile)


def classify(explist: parse_explist, *, classifier=None, movlist: parse_movlist=None, hpc=False, hpc_options: parse_hpc_options=' ',
             nw=0, session=None, usepassed=False, dont_use_min_conf=False, consv_factor=None):

    if not hpc:
        from antrax.classifier import axClassifier

    from_expdir = classifier is None

    if not hpc and not from_expdir:

        c = axClassifier.load(classifier)

    for e in explist:

        if from_expdir:
            classifier = e.sessiondir + '/classifier/classifier.h5'

        if hpc:
            hpc_options['classifier'] = classifier
            hpc_options['movlist'] = movlist
            antrax_hpc_job(e, 'classify', opts=hpc_options)
        else:
            if from_expdir:
                c = axClassifier.load(classifier)
            c.predict_experiment(e, movlist=movlist)


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
        'validate': validate,
        'track': track,
        'train': train,
        'classify': classify,
        'solve': solve,
        'dlc': dlc
    }

    run(function_list)
