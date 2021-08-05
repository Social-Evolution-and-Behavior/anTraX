
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
from . import temperature_project_utils as tpu
from subprocess import Popen
import time

ANTRAX_USE_MCR = os.getenv('ANTRAX_USE_MCR') == 'True'
ANTRAX_HPC = os.getenv('ANTRAX_HPC') == 'True'


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

'''
def exportxy_untagged(explist, *, movlist: parse_movlist=None, mcr=ANTRAX_USE_MCR, nw=2, hpc=ANTRAX_HPC, hpc_options: parse_hpc_options={},
                missing=False, session=None, dry=False):

    explist = parse_explist(explist, session)

    if hpc:
        for e in explist:
            hpc_options['dry'] = dry
            hpc_options['movlist'] = movlist
            hpc_options['missing'] = missing
            antrax_hpc_job(e, 'exportxy-untagged', opts=hpc_options)
    else:

        Q = MatlabQueue(nw=nw, mcr=mcr)

        for e in explist:
            movlist1 = e.movlist if movlist is None else movlist
            for m in movlist1:
                Q.put(('export_untagged_single_movie', e, m))

            # wait for tasks to complete

        Q.join()

        # close
        Q.stop_workers()
'''


def make_event_clips(explist, *, session=None, nw=2, downsample=1, speedup=1, missing=False, pre=300, ow=False, refexpdir='', before=0, ffmpeg=False):

    explist = parse_explist(explist, session)

    if not ffmpeg:
        Q = MatlabQueue(nw=nw, mcr=False)

    useref = is_expdir(refexpdir)

    if useref:

        eref = axExperiment(refexpdir)
        tdref = tpu.axTempData(eref, movlist=eref.movlist)
        cond = tdref.frmdata['S1'].values > 27.5
        cond = np.diff(cond.astype('float'))

        ev_onset = np.where(cond == 1)[0] + 2
        ev_offset = np.where(cond == -1)[0]
        ev_index = range(len(ev_onset))
        ev_temp = tdref.frmdata['S1'][ev_onset].values.astype('int')

        ev_onset = ev_onset - 10 * pre

        report('I', 'will make ' + str(len(ev_onset)) + ' event clips (ref used)')



    for e in explist:

        mkdir(join(e.sessiondir, 'clips'))

        td = tpu.axTempData(e, movlist=e.movlist)

        if not useref:

            cond = td.frmdata['S1'].values > 27.5
            dcond = np.diff(cond.astype('float'))

            ev_onset = np.where(dcond == 1)[0] + 2
            ev_offset = np.where(dcond == -1)[0]

            if cond[0]:
                ev_onset = np.insert(ev_onset, 0, 0)

            if cond[-1]:
                ev_offset = np.append(ev_offset, len(cond)-1)

            ev_index = range(len(ev_onset))

            ev_temp = td.frmdata['S1'][ev_onset].values.astype('int')

            ev_onset = ev_onset - 10*pre

            ev_mi  = [e.get_m_mf(f)[0] for f in ev_onset]
            ev_mfi = [e.get_m_mf(f)[1] for f in ev_onset]
            ev_mf  = [e.get_m_mf(f)[0] for f in ev_offset]
            ev_mff = [e.get_m_mf(f)[1] for f in ev_offset]

            report('I', 'will make ' + str(len(ev_onset)) + ' event clips')

            ev_table = pd.DataFrame({
                                        'num': ev_index,
                                        'T': ev_temp,
                                        'mi': ev_mi,
                                        'mfi': ev_mfi,
                                        'fi': ev_onset,
                                        'mf': ev_mf,
                                        'mff': ev_mff,
                                        'ff': ev_offset,
                                    })

            ev_table.to_csv(e.sessiondir + '/clips/event_table.csv')

        for ix, row in ev_table.iterrows():
        #for ix, fi, ff, s in zip(ev_index, ev_onset, ev_offset, ev_temp):

            outfile = e.sessiondir + '/clips/event_' + str(ix+1) + '_' + str(row['T']) + '.mp4'

            if isfile(outfile) and not ow:
                report('I', 'clip exists, skipping')
                continue

            if ffmpeg:
                tmpfiles = []
                for m in range(row['mi'], row['mf']+1):
                    timei = int(row['mfi'] / e.framerate) if m == row['mi'] else None
                    timef = int(row['mff'] / e.framerate) if m == row['mf'] else None

                    infile = e.viddir + '/' + e.m_info(m)['subdir'] + '/' + e.m_info(m)['movfile']

                    outfile = e.sessiondir + '/clips/tmp_' + str(ix) + '_' + str(m) + '.mp4'
                    cmd = 'ffmpeg -loglevel error  -i ' + infile
                    if timei is not None:
                        cmd += ' -ss ' + time.strftime('%H:%M:%S', time.gmtime(timei))
                    cmd += ' -c copy'
                    if timef is not None:
                        cmd += ' -to ' + time.strftime('%H:%M:%S', time.gmtime(timef))
                    cmd += ' ' + outfile
                    p = Popen(cmd, shell=True)
                    p.wait()
                    tmpfiles += [outfile]
                # concat
                listfile = e.sessiondir + '/clips/event_' + str(ix + 1) + '.txt'
                with open(listfile, 'w') as f:
                    for item in tmpfiles:
                        if os.path.getsize(item) > 1000:
                            f.write("file %s\n" % item)

                outfile = e.sessiondir + '/clips/event_' + str(ix + 1) + '_' + str(row['T']) + '.mp4'
                cmd = 'ffmpeg -f concat -safe 0 -i ' + listfile + ' -c copy ' + outfile
                p = Popen(cmd, shell=True)
                p.wait()

                # delete tmp files
                # for file in tmpfiles:
                #    os.remove(file)

                continue

            w = {'fun': 'make_annotated_video'}
            dfile = e.logsdir + '/matlab_event_clip_' + str(ix) + '.log'
            w['args'] = [e.expdir, 'fi', int(fi-before), 'ff', int(ff),
                         'annotate_tracks', False,
                         'bgcorrect', False,
                         'outline', False,
                         'mask', False,
                         'downsample', float(downsample),
                         'speedup', float(speedup),
                         'outfile', outfile]
            w['diary'] = dfile
            w['str'] = 'making event #' + str(ix) + ' clip'

            if not ffmpeg and (not missing or not isfile(outfile)):
                Q.put(w)

    if not ffmpeg:
        Q.join()
        Q.stop_workers()


def compute_medians(explist, *, movlist: parse_movlist=None, nw=2, hpc=ANTRAX_HPC, hpc_options: parse_hpc_options={},
                missing=False, session=None, dry=False):

    explist = parse_explist(explist, session)

    Q = AnalysisQueue(nw=nw)

    for e in explist:
        movlist1 = e.movlist if movlist is None else movlist
        for m in movlist1:
            item = ('tpu.compute_medians', [e], {'movlist': [m]})
            Q.put(item)

    Q.join()
    Q.stop_workers()


def compute_nest_location(explist, *, movlist: parse_movlist=None, nw=2, hpc=ANTRAX_HPC, hpc_options: parse_hpc_options={},
                missing=False, session=None, dry=False, window=36001):

    explist = parse_explist(explist, session)

    nw = min([nw, len(explist)])

    Q = AnalysisQueue(nw=nw)

    for e in explist:
        movlist1 = e.movlist if movlist is None else movlist
        item = ('tpu.compute_nest_location', [e], {'movlist': movlist1, 'K': window})
        Q.put(item)

    Q.join()
    Q.stop_workers()


def compute_measures(explist, *, movlist: parse_movlist=None, nw=2, hpc=ANTRAX_HPC, hpc_options: parse_hpc_options={},
                missing=False, session=None, dry=False):

    explist = parse_explist(explist, session)

    Q = AnalysisQueue(nw=nw)

    for e in explist:
        movlist1 = e.movlist if movlist is None else movlist
        for m in movlist1:
            item = ('tpu.compute_measures', [e], {'movlist': [m]})
            Q.put(item)

    Q.join()
    Q.stop_workers()


def extract_events(explist, *, movlist: parse_movlist=None, nw=2, hpc=ANTRAX_HPC, hpc_options: parse_hpc_options={},
                missing=False, session=None, dry=False):

    explist = parse_explist(explist, session)


def exportxy_untagged(explist, *, movlist: parse_movlist=None, nw=2, session=None, missing=False,
                      hpc=ANTRAX_HPC, hpc_options: parse_hpc_options={}):

    explist = parse_explist(explist, session)

    ex = explist[0]

    if movlist is None:
        movlist = ex.movlist

    if missing:
        movlist = [m for m in ex.get_missing(ftype='xy_untagged_h5') if m in movlist]

    Q = AnalysisQueue(nw=nw)

    for m in movlist:
        item = ('tpu.exportxy_untagged', [ex], {'movlist': [m]})
        Q.put(item)

    Q.join()
    Q.stop_workers()


def workflow_untagged(explist, *, movlist: parse_movlist=None, nw=2, nants=0, hpc=ANTRAX_HPC, hpc_options: parse_hpc_options={},
                missing=False, session=None, dry=False, window=36001, step='all'):

    explist = parse_explist(explist, session)

    ex = explist[0]

    if nants == 0:
        report('E', 'Please provide number of ants with --nants')
        return

    if nants > 0:
        ex.nants = nants

    if movlist is None:
        movlist = ex.movlist

    if missing:
        movlist = [m for m in ex.get_missing(ftype='frmdata') if m in movlist]
        report('I', 'Running for videos ' + str(movlist))

    Q = AnalysisQueue(nw=nw)

    if step in ['all', '1', 'compute_medians']:
        for m in movlist:
            item = ('tpu.compute_medians', [ex], {'movlist': [m]})
            Q.put(item)

        Q.join()

    if step in ['all', '2', 'compute_nest_location']:
        for m in movlist:
            item = ('tpu.compute_nest_location', [ex], {'movlist': [m], 'K': window})
            Q.put(item)

        Q.join()

        frmdatadir = join(ex.sessiondir, 'frmdata')
        for m in movlist:
            f1 = join(frmdatadir, 'frmdata_' + str(m) + '.csv.tmp')
            f2 = join(frmdatadir, 'frmdata_' + str(m) + '.csv')
            os.remove(f2)
            os.rename(f1, f2)

    if step in ['all', '3', 'compute_measures']:
        for m in movlist:
            item = ('tpu.compute_measures', [ex], {'movlist': [m]})
            Q.put(item)

        Q.join()

    Q.stop_workers()


class AnalysisQueue(queue.Queue):

    def __init__(self, nw=None):

        super().__init__()
        self.threads = []
        self.nw = nw
        if nw is not None:
            self.start_workers()

    def worker(self):

        while True:
            item = self.get()
            #print(item)
            if item is None:
                break
            fun = eval(item[0])
            args = item[1] if len(item) > 1 else []
            kwargs = item[2] if len(item) > 2 else {}
            fun(*args, **kwargs)

            self.task_done()

    def start_workers(self):

        threads = []

        report('I', 'Starting ' + str(self.nw) + ' workers')
        for i in range(self.nw):
            t = Thread(target=self.worker)
            t.start()
            threads.append(t)

        self.threads = threads

    def stop_workers(self, wait=True):

        for i in range(self.nw):
            self.put(None)

        if wait:
            for t in self.threads:
                t.join()

        report('I', 'Workers closed')


def main():

    function_list = {
        'exportxy-untagged': exportxy_untagged,
        'compute-medians': compute_medians,
        'compute-nest-location': compute_nest_location,
        'compute-measures': compute_measures,
        'workflow-untagged': workflow_untagged,
        'extract-events': extract_events,
        'make-event-clips': make_event_clips,
    }

    run(function_list, description="""
    anTraX is a software for high-throughput tracking of color tagged insects, for full documentation, see antrax.readthedocs.io
    
    """)
