
from clize import run, parser
from imageio import imread
from . import *
from .matlab import *
from .hpc import antrax_hpc_job, antrax_hpc_train_job
from .utils import *
import os

ANTRAX_USE_MCR = os.getenv('ANTRAX_USE_MCR') == 'True'
ANTRAX_HPC = os.getenv('ANTRAX_HPC') == 'True'
JAABA_PATH = os.getenv('ANTRAX_JAABA_PATH')


########################### AUX functions #########################


@parser.value_converter
def to_int(arg):

    if arg is not None:
        return int(arg)
    else:
        return None


@parser.value_converter
def to_float(arg):

    if arg is not None:
        return float(arg)
    else:
        return None


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

    if movlist == '0':
        movlist = []
    else:
        movlist = parse_movlist_str(movlist)

    return movlist


# @parser.value_converter
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


def compile_antrax():
    """Compile antrax executables"""

    compile_antrax_executables()


def configure(expdir=None, *, mcr=ANTRAX_USE_MCR):
    """Launch antrax configuration app"""

    report('D', 'antrax cli entry point')
    args = [expdir] if expdir is not None else []
    launch_matlab_app('antrax', args, mcr=mcr)


def extract_trainset(expdir, *, session=None, mcr=ANTRAX_USE_MCR):
    """Launch antrax trainset extraction app"""

    args = [expdir] if session is None else [expdir, 'session', session]
    launch_matlab_app('validate_classifications', args, mcr=mcr)


def merge_trainset(source, target):
    """Merge two trainsets"""

    mkdir(target)
    mkdir(target + '/examples')

    source_labels = classes_from_examplesdir(source + '/examples/')
    totcnt = 0
    for sl in source_labels:

        mkdir(target + '/examples/' + sl)

        sfiles = glob(source + '/examples/' + sl + '/*.png')
        tfiles = [sf.replace(source, target) for sf in sfiles]
        cnt = 0
        for sf, tf in zip(sfiles, tfiles):
            shutil.copyfile(sf, tf)
            cnt += 1
        totcnt += cnt
        report('I', '...copied ' + str(cnt) + ' images for label ' + sl)

    report('I', 'Copied total of ' + str(totcnt) + ' images')


def graph_explorer(expdir, *, m=0, session=None, mcr=ANTRAX_USE_MCR):
    """Launch graph-explorer app"""

    args = [expdir, 'm', m] if session is None else [expdir, 'm', m, 'session', session]
    launch_matlab_app('graph_explorer_app', args, mcr=mcr)


def validate(expdir, *, session=None, mcr=ANTRAX_USE_MCR):
    """Launch antrax validation app"""

    args = [expdir] if session is None else [expdir, 'session', session]
    launch_matlab_app('validate_tracking', args, mcr=mcr)


def export_dlc(expdir, dlcdir, *, session=None, movlist: parse_movlist=None, antlist=None, nimages=100,
               video=False, username='anTraX'):
    """Export trainset for DeepLabCut"""

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


def pair_search(explist, *, movlist: parse_movlist=None, mcr=False, nw=2, hpc=False, hpc_options: parse_hpc_options={},
                missing=False, session=None, dry=False):

    explist = parse_explist(explist, session)
    mcr = mcr or ANTRAX_USE_MCR
    hpc = hpc or ANTRAX_HPC

    if hpc:
        for e in explist:
            hpc_options['dry'] = dry
            hpc_options['movlist'] = movlist
            hpc_options['missing'] = missing
            antrax_hpc_job(e, 'pair-search', opts=hpc_options)
    else:

        Q = MatlabQueue(nw=nw, mcr=mcr)

        for e in explist:
            movlist1 = e.movlist if movlist is None else movlist
            for m in movlist1:
                w = {'fun': 'pair_search'}
                w['args'] = [e.expdir, m, 'trackingdirname', e.session]
                w['diary'] = join(e.logsdir, 'matlab_pair_search_m_' + str(m) + '.log')
                w['str'] = 'pair search movie ' + str(m)
                Q.put(('pair_search', e, m))

            # wait for tasks to complete

        Q.join()

        # close
        Q.stop_workers()


def track(explist, *, movlist: parse_movlist=None, mcr=False, classifier=None, onlystitch=False, nw=2, hpc=False,
          hpc_options: parse_hpc_options={}, missing=False, session=None, dry=False):
    """Run tracking step"""

    explist = parse_explist(explist, session)
    mcr = mcr or ANTRAX_USE_MCR
    hpc = hpc or ANTRAX_HPC

    if hpc:

        report('D', '--tracking on hpc--')
        for e in explist:
            report('D', '--tracking experiment ' + e.expname + '--')
            hpc_options['dry'] = dry
            hpc_options['missing'] = missing
            hpc_options['classifier'] = classifier
            hpc_options['movlist'] = movlist
            antrax_hpc_job(e, 'track', opts=hpc_options)

    else:

        Q = MatlabQueue(nw=nw, mcr=mcr)

        if not onlystitch:
            for e in explist:
                movlist1 = e.movlist if movlist is None else movlist
                for m in movlist1:
                    w = {'fun': 'track_single_movie'}
                    w['args'] = [e.expdir, m, 'trackingdirname', e.session]
                    w['diary'] = join(e.logsdir, 'matlab_track_m_' + str(m) + '.log')
                    w['str'] = 'track movie ' + str(m)
                    Q.put(w)

            # wait for tasks to complete
            Q.join()

        # run cross movie link
        for e in explist:
            w = {'fun': 'link_across_movies'}
            w['args'] = [e.expdir, 'trackingdirname', e.session]
            w['diary'] = join(e.logsdir, 'matlab_link_across_movies.log')
            w['str'] = 'link scross movies'
            Q.put(w)

        # close
        Q.stop_workers()


def solve(explist, *, glist: parse_movlist=None, movlist: parse_movlist=None, clist: parse_movlist=None, mcr=False, untagged=False,
          nw=2, hpc=False, hpc_options: parse_hpc_options={}, missing=False, session=None, dry=False, csv=False, step=0):
    """Run propagation step"""

    explist = parse_explist(explist, session)
    mcr = mcr or ANTRAX_USE_MCR
    hpc = hpc or ANTRAX_HPC

    if hpc:

        for e in explist:

            eglist = glist if glist is not None else e.glist

            emlist = [e.ggroups[g - 1] for g in eglist]
            emlist = [m for grp in emlist for m in grp]

            if movlist is not None:
                emlist = [m for m in emlist if m in movlist]

            hpc_options['dry'] = dry
            hpc_options['classifier'] = classifier
            hpc_options['missing'] = missing
            hpc_options['glist'] = eglist
            hpc_options['movlist'] = emlist
            hpc_options['untagged'] = untagged

            if e.prmtrs['geometry_multi_colony']:
                eclist = clist if clist is not None else e.clist
                for c in eclist:
                    hpc_options['c'] = c
                    hpc_options['waitfor'] = None
                    if step == 0 or step == 1:
                        jid = antrax_hpc_job(e, 'solve', opts=hpc_options, solve_step=1)
                        hpc_options['waitfor'] = jid
                    if step == 0 or step == 2:
                        jid = antrax_hpc_job(e, 'solve', opts=hpc_options, solve_step=2)
                        hpc_options['waitfor'] = jid
                    if step == 0 or step == 3:
                        jid = antrax_hpc_job(e, 'solve', opts=hpc_options, solve_step=3)
            else:
                hpc_options['c'] = None
                hpc_options['waitfor'] = None
                if step == 0 or step == 1:
                    jid = antrax_hpc_job(e, 'solve', opts=hpc_options, solve_step=1)
                    hpc_options['waitfor'] = jid
                if step == 0 or step == 2:
                    jid = antrax_hpc_job(e, 'solve', opts=hpc_options, solve_step=2)
                    hpc_options['waitfor'] = jid
                if step == 0 or step == 3:
                    jid = antrax_hpc_job(e, 'solve', opts=hpc_options, solve_step=3)

    else:

        Q = MatlabQueue(nw=nw, mcr=mcr)

        for e in explist:

            eglist = glist if glist is not None else e.glist
            eclist = clist if clist is not None else e.clist
            emlist = [e.ggroups[g - 1] for g in eglist]
            emlist = [m for grp in emlist for m in grp]
            if movlist is not None:
                emlist = [m for m in emlist if m in movlist]

            if step == 0 or step == 1:
                if e.prmtrs['geometry_multi_colony']:
                    for c in eclist:
                        for m in emlist:
                            w = {'fun': 'solve_single_movie'}
                            w['args'] = [e.expdir, m, 'trackingdirname', e.session, 'colony', c]
                            w['diary'] = join(e.logsdir, 'matlab_solve_m_' + str(m) + '_c_' + str(c) + '.log')
                            w['str'] = 'solve colony ' + str(c) + ' movie ' + str(m)
                            Q.put(w)
                else:
                    for m in emlist:
                        w = {'fun': 'solve_single_movie'}
                        w['args'] = [e.expdir, m, 'trackingdirname', e.session]
                        w['diary'] = join(e.logsdir, 'matlab_solve_m_' + str(m) + '.log')
                        w['str'] = 'solve movie ' + str(m)
                        Q.put(w)

                # wait for single movie tasks to complete
                Q.join()

            # stitch
            if step == 0 or step == 2:
                if e.prmtrs['geometry_multi_colony']:
                    for c in eclist:
                        for g in eglist:
                            w = {'fun': 'solve_across_movies'}
                            w['args'] = [e.expdir, g, 'trackingdirname', e.session, 'colony', c]
                            w['diary'] = join(e.logsdir, 'matlab_solve_g_' + str(g) + '_c_' + str(c) + '.log')
                            w['str'] = 'solve stitch colony ' + str(c) + ' graph ' + str(g)
                            Q.put(w)
                else:
                    for g in eglist:
                        w = {'fun': 'solve_across_movies'}
                        w['args'] = [e.expdir, g, 'trackingdirname', e.session]
                        w['diary'] = join(e.logsdir, 'matlab_solve_g_' + str(g) + '.log')
                        w['str'] = 'solve stitch graph ' + str(g)
                        Q.put(w)

                # wait for stitch to finish
                Q.join()

            if step == 0 or step == 3:
                if e.prmtrs['geometry_multi_colony']:
                    for c in eclist:
                        for m in emlist:
                            w = {'fun': 'export_single_movie'}
                            w['args'] = [e.expdir, m, 'trackingdirname', e.session, 'colony', c, 'untagged', untagged, 'csv', csv]
                            w['diary'] = join(e.logsdir, 'matlab_export_m_' + str(m) + '_c_' + str(c) + '.log')
                            w['str'] = 'export colony ' + str(c) + ' movie ' + str(m)
                            Q.put(w)
                else:
                    for m in emlist:
                        w = {'fun': 'export_single_movie'}
                        w['args'] = [e.expdir, m, 'trackingdirname', e.session, 'untagged', untagged, 'csv', csv]
                        w['diary'] = join(e.logsdir, 'matlab_export_m_' + str(m) + '.log')
                        w['str'] = 'export movie ' + str(m)
                        Q.put(w)

                # wait for stitch to finish
                Q.join()

        # close
        Q.stop_workers()


def train(classdir,  *, name='classifier', scratch=False, ne=5, unknown_weight=20, multi_weight=0.1, arch='small',
          modelfile=None, target_size: to_int=None, crop_size: to_int=None, hsymmetry=False, aug_options='',
          hpc=False, hpc_options: parse_hpc_options={}, background='white', dry=False):
    """Train a blob classifier"""

    hpc = hpc or ANTRAX_HPC

    if not is_classdir(classdir):

        if is_expdir(classdir):
            ex = axExperiment(classdir)
            classdir = join(ex.sessiondir, 'classifier')

    if not is_classdir(classdir):
        report('E', 'bad classifier directory')
        return

    classfile = join(classdir, name + '.h5')

    examplesdir = join(classdir, 'examples')

    if scratch or not isfile(classfile):

        n = len(glob(examplesdir + '/*'))
        if target_size is None:
            f = glob(examplesdir + '/*/*.png')[0]
            target_size = max(imread(f).shape)

        c = axClassifier(name, nclasses=n, target_size=target_size, crop_size=crop_size, hsymmetry=hsymmetry, background=background,
                         unknown_weight=unknown_weight, multi_weight=multi_weight, modeltype=arch, json=modelfile)

        c.save(classfile)

    if hpc:
        hpc_options['dry'] = dry
        hpc_options['name'] = name
        hpc_options['ne'] = ne

        antrax_hpc_train_job(classdir, aug_options=aug_options, opts=hpc_options)

        return

    else:

        c = axClassifier.load(classfile)
        c.train(examplesdir, ne=ne, aug_options=aug_options)
        c.save(classfile)


def classify(explist, *, classifier=None, movlist: parse_movlist=None, hpc=False, hpc_options: parse_hpc_options={},
             nw=0, session=None, usepassed=False, dont_use_min_conf=False, consv_factor=None, report=False, dry=False,
             missing=False):
    """Run classification step"""

    explist = parse_explist(explist, session)
    hpc = hpc or ANTRAX_HPC

    if not hpc:
        from antrax.classifier import axClassifier

    from_expdir = classifier is None

    if not hpc and not from_expdir:

        c = axClassifier.load(classifier)

    for e in explist:

        if from_expdir:
            classifier = e.sessiondir + '/classifier/classifier.h5'

        if hpc:
            hpc_options['dry'] = dry
            hpc_options['classifier'] = classifier
            hpc_options['movlist'] = movlist
            hpc_options['missing'] = missing
            antrax_hpc_job(e, 'classify', opts=hpc_options)
        else:
            if from_expdir:
                c = axClassifier.load(classifier)
            c.predict_experiment(e, movlist=movlist, report=True)


def dlc(explist, *, cfg, movlist: parse_movlist=None, session=None, hpc=False, hpc_options: parse_hpc_options=' ',
        missing=False, dry=False):
    """Run DeepLabCut on antrax experiments

     :param explist: path to experiment folder, path to file with experiment folders, path to a folder
                     containing several experiments
     :param session: run on specific session
     :param cfg: Full path to DLC project config file
     :param movlist: List of video indices to run (default is all)
     :param hpc: Run using slurm worload maneger (default is False)
     :param hpc_options: comma separated list of options for hpc run
     """

    explist = parse_explist(explist, session)
    hpc = hpc or ANTRAX_HPC

    for e in explist:
        if hpc:
            hpc_options['dry'] = dry
            hpc_options['cfg'] = cfg
            hpc_options['movlist'] = movlist
            hpc_options['missing'] = missing
            antrax_hpc_job(e, 'dlc', opts=hpc_options)
        else:
            from antrax.dlc import dlc4antrax
            print('Running DeepLabCut on experiment ' + e.expname)
            dlc4antrax(e, dlccfg=cfg, movlist=movlist)


def exportxy(explist, *, movlist: parse_movlist=None, session=None, nw=2, mcr=False, hpc=False, hpc_options: parse_hpc_options={}, missing=False, dry=False, untagged=False, csv=False):
    """Export xy data"""

    solve(explist, movlist=movlist, session=session, nw=nw, mcr=mcr, hpc=hpc, step=3, hpc_options=hpc_options,
          missing=missing, dry=dry, untagged=untagged, csv=csv)


def export_jaaba(explist, *, movlist: parse_movlist=None, session=None, nw=2, mcr=False, hpc=False,
                 missing=False, dry=False, hpc_options: parse_hpc_options=' '):
    """Export data to JAABA"""

    mcr = mcr or ANTRAX_USE_MCR
    hpc = hpc or ANTRAX_HPC

    if mcr or hpc:
        print('')
        print('antrax does not currently support jaaba commands in MCR mode')
        print('')
        return

    explist = parse_explist(explist, session)

    if hpc:

        for e in explist:
            hpc_options['dry'] = dry
            hpc_options['movlist'] = movlist
            hpc_options['missing'] = missing
            antrax_hpc_job(e, 'export_jaaba', opts=hpc_options)
    else:

        Q = MatlabQueue(nw=nw, mcr=mcr)

        for e in explist:

            movlist1 = e.movlist if movlist is None else movlist
            for m in movlist1:
                w = {}
                w['fun'] = 'prepare_data_for_jaaba'
                w['args'] = [e.expdir, 'movlist', m, 'trackingdirname', e.session, 'jaaba_path', JAABA_PATH]
                w['diary'] = join(e.logsdir, 'matlab_export_jaaba_m_' + str(m) + '.log')
                w['str'] = 'JAABA export movie ' + str(m)
                Q.put(w)

        # wait for tasks to complete
        Q.join()

        # close
        Q.stop_workers()


def run_jaaba(explist, *, movlist: parse_movlist=None, session=None, nw=2, jab=None, mcr=False, hpc=False,
              missing=False, hpc_options: parse_hpc_options=' ', dry=False):
    """Run JAABA classifier on antrax experiments"""

    mcr = mcr or ANTRAX_USE_MCR
    hpc = hpc or ANTRAX_HPC

    if mcr or hpc:
        print('')
        print('antrax does not currently support jaaba commands in MCR mode')
        print('')
        return

    explist = parse_explist(explist, session)

    if jab is None:
        print('E', 'jab file must be given as argument')
        return

    if hpc:

        for e in explist:
            hpc_options['dry'] = dry
            hpc_options['movlist'] = movlist
            hpc_options['missing'] = missing
            hpc_options['jab'] = jab
            antrax_hpc_job(e, 'export_jaaba', opts=hpc_options)
    else:

        Q = MatlabQueue(nw=nw, mcr=mcr)

        for e in explist:
            movlist1 = e.movlist if movlist is None else movlist
            for m in movlist1:
                w = {}
                w['fun'] = 'run_jaaba_detect'
                w['args'] = [e.expdir, 'movlist', m, 'jab', jab, 'trackingdirname', e.session, 'jaaba_path',
                             JAABA_PATH, 'antrax_path', ANTRAX_PATH]
                w['diary'] = join(e.logsdir, 'matlab_export_jaaba_m_' + str(m) + '.log')
                w['str'] = 'JAABA run ' + e.expname + ' movie ' + str(m)
                Q.put(w)

        # wait for tasks to complete
        Q.join()

        for e in explist:
            w = {}
            w['fun'] = 'import_jaaba_results'
            w['args'] = [e.expdir, e.session]
            w['diary'] = join(e.logsdir, 'matlab_jaaba_results.log')
            w['str'] = 'Collecting JAABA results for ' + e.expname
            Q.put(w)

        # wait for tasks to complete
        Q.join()

        # close
        Q.stop_workers()


def main():

    function_list = {
        'configure': configure,
        'extract-trainset': extract_trainset,
        'merge-trainset': merge_trainset,
        'graph-explorer': graph_explorer,
        'export-dlc-trainset': export_dlc,
        'export-jaaba': export_jaaba,
        'run-jaaba': run_jaaba,
        'validate': validate,
        'track': track,
        'train': train,
        'classify': classify,
        'solve': solve,
        'exportxy': exportxy,
        'dlc': dlc,
        'pair-search': pair_search,
        'compile': compile_antrax
    }

    # print welcome message
    print('')
    print('==================================================================================')
    print('')
    print('Welcome to anTraX - a software for tracking color tagged ants (and other insects)')
    print('')
    print('==================================================================================')
    print('')

    run(function_list, description="""
    anTraX is a software for high-throughput tracking of color tagged insects, for full documentation,
    see antrax.readthedocs.io
    """)
