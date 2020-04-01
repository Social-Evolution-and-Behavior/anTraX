
from clize import run, Parameter, parser
from sigtools.wrappers import decorator
import os
from os.path import isfile, isdir, join, splitext
from glob import glob
from time import sleep
from imageio import imread
from . import *
from .matlab import *
from .hpc import antrax_hpc_job, antrax_hpc_train_job
from .utils import *



########################### AUX functions #########################

@parser.value_converter
def parse_hpc_options(s):

    if s is None or s == ' ':
        return {}

    opts = {x.split('=')[0]: x.split('=')[1] for x in s.split(',') if '=' in x}
    for k, v in opts.items():
        if v.isnumeric():
            opts[k] = int(v)

    if 'rockefeller' in HOSTNAME:
        opts['email'] = opts.get('email', USER + '@mail.rockefeller.edu')

    return opts


@parser.value_converter
def parse_movlist(movlist):

    movlist = parse_movlist_str(movlist)

    return movlist

#@parser.value_converter
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
                    exps.append(axExperiment(lineparts[0], session))
    elif isdir(exparg):
        explist = find_expdirs(exparg)
        exps = [axExperiment(e, session) for e in explist if is_expdir(e)]
    else:
        print('Something wrong with explist argument')
        exps = []

    return exps


########################### Run functions ##########################


def configure(expdir=None):
    """Launch antrax configuration app"""

    args = [expdir] if expdir is not None else []
    launch_matlab_app('antrax', args)


def extract_trainset(expdir, *, session=None):
    """Launch antrax configuration app"""

    args = [expdir] if session is None else [expdir, 'session', session]
    launch_matlab_app('verify_autoids_app', args)

def merge_trainset(source, target):

    mkdir(target)
    mkdir(target + '/examples')

    source_labels = classes_from_examplesdir(source + '/examples/')

    for sl in source_labels:

        mkdir(target + '/examples/' + sl)

        sfiles = glob(source + '/examples/' + sl + '/*.png')
        tfiles = [sf.replace(source, target) for sf in sfiles]

        for sf, tf in zip(sfiles, tfiles):
            shutil.copyfile(sf, tf)

def graph_explorer(expdir, *, session=None):

    args = [expdir] if session is None else [expdir, 'session', session]
    launch_matlab_app('graph_explorer', args)

def validate(expdir, *, session=None):
    """Launch antrax configuration app"""

    args = [expdir] if session is None else [expdir, 'session', session]
    launch_matlab_app('verify_tracking', args)

def export_dlc(expdir, dlcdir, *, session=None, movlist: parse_movlist=None, antlist=None, nimages=100, video=False, username='anTraX'):

    import deeplabcut as dlc
    from antrax.dlc import  create_trainset


    ex = axExperiment(expdir, session)

    if isdir(dlcdir) and not isfile(dlcdir + '/config.yaml'):
        report('E', 'directory exists, but does contain a deeplabcut configuration file! check your parameters')
        return

    if not isdir(dlcdir):

        report('I', 'DLC project does not exists, creating')
        pathlist = os.path.normpath(dlcdir).split(os.path.sep)
        wd = os.path.sep.join(pathlist[:-1])
        projname = pathlist[-1]
        dlcdir = dlc.create_new_project(projname, username, [], working_directory=wd)

    create_trainset(ex, dlcdir, n=nimages, antlist=antlist, movlist=movlist, vid=video)


def track(explist, *, movlist: parse_movlist=None, mcr=False, classifier=None, onlystitch=False, nw=2, hpc=False, hpc_options: parse_hpc_options={},
          session=None):

    explist = parse_explist(explist, session)

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


def solve(explist, *, glist: parse_movlist=None, clist: parse_movlist=None, mcr=False, nw=2, hpc=False, hpc_options: parse_hpc_options={},
          session=None):

    explist = parse_explist(explist, session)

    if hpc:

        for e in explist:

            hpc_options['classifier'] = classifier
            hpc_options['glist'] = glist if glist is not None else e.glist

            if e.prmtrs['geometry_multi_colony']:
                eclist = clist if clist is not None else e.clist
                for c in eclist:
                    hpc_options['c'] = c
                    antrax_hpc_job(e, 'solve', opts=hpc_options)
            else:
                hpc_options['c'] = None
                antrax_hpc_job(e, 'solve', opts=hpc_options)

    else:

        Q = MatlabQueue(nw=nw, mcr=mcr)

        for e in explist:

            eglist = glist if glist is not None else e.glist
            eclist = clist if clist is not None else e.clist

            if e.prmtrs['geometry_multi_colony']:
                for c in eclist:
                    for g in eglist:
                        Q.put(('solve_single_graph', e, g, c))
            else:
                for g in eglist:
                    Q.put(('solve_single_graph', e, g, None))

        # wait for tasks to complete
        Q.join()

        # close
        Q.stop_workers()


def train(classdir,  *, name='classifier', scratch=False, ne=5, unknown_weight=20, multi_weight=0.5, verbose=1, target_size=None, crop_size=None,
          hpc=False, hpc_options: parse_hpc_options={}):


    if target_size is not None:
        target_size = int(target_size)

    if crop_size is not None:
        crop_size = int(crop_size)


    if hpc:

        hpc_options['scratch'] = scratch
        hpc_options['target_size'] = target_size
        hpc_options['crop_size'] = crop_size
        hpc_options['multi_weight'] = multi_weight
        hpc_options['unknown_weight'] = unknown_weight
        hpc_options['name'] = name
        hpc_options['ne'] = ne

        antrax_hpc_train_job(classdir, opts=hpc_options)

        return

    classfile = join(classdir, name + '.h5')
    examplesdir = join(classdir, 'examples')

    if isfile(classfile):
        c = axClassifier.load(classfile)
    else:
        n = len(glob(examplesdir + '/*'))
        if target_size is None:
            f = glob(examplesdir + '/*/*.png')[0]
            target_size = max(imread(f).shape)

        c = axClassifier(name, nclasses=n, target_size=target_size, crop_size=crop_size)

    c.train(examplesdir, from_scratch=scratch, ne=ne, multi_weight=multi_weight, unknown_weight=unknown_weight)
    c.save(classfile)


def classify(explist, *, classifier=None, movlist: parse_movlist=None, hpc=False, hpc_options: parse_hpc_options={},
             nw=0, session=None, usepassed=False, dont_use_min_conf=False, consv_factor=None, report=False):

    explist = parse_explist(explist, session)

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
            c.predict_experiment(e, movlist=movlist, report=report)


def dlc(explist, *, cfg, movlist: parse_movlist=None, session=None, hpc=False, hpc_options: parse_hpc_options=' '):
    """Run DeepLabCut on antrax experiment

     :param explist: path to experiment folder, path to file with experiment folders, path to a folder containing several experiments
     :param session: run on specific session
     :param cfg: Full path to DLC project config file
     :param movlist: List of video indices to run (default is all)
     :param hpc: Run using slurm worload maneger (default is False)
     :param hpc_options: comma separated list of options for hpc run
     """

    explist = parse_explist(explist, session)

    for e in explist:
        if hpc:
            hpc_options['cfg'] = cfg
            hpc_options['movlist'] = movlist
            antrax_hpc_job(e, 'dlc', opts=hpc_options)
        else:
            from antrax.dlc import dlc4antrax
            print('Running DeepLabCut on experiment ' + e.expname)
            dlc4antrax(e, dlccfg=cfg, movlist=movlist)


def export_jaaba(explist, *, movlist: parse_movlist=None, session=None, hpc=False, hpc_options: parse_hpc_options=' '):


    explist = parse_explist(explist, session)

    for e in explist:
        if hpc:
            hpc_options['movlist'] = movlist
            antrax_hpc_job(e, 'export_jaaba', opts=hpc_options)
        else:
            pass



def main():

    function_list = {
        'configure': configure,
        'extract-trainset': extract_trainset,
        'merge-trainset': merge_trainset,
        'graph-explorer': graph_explorer,
        'export-dlc-trainset': export_dlc,
        'export-jaaba': export_jaaba,
        'validate': validate,
        'track': track,
        'train': train,
        'classify': classify,
        'solve': solve,
        'dlc': dlc
    }

    run(function_list)
