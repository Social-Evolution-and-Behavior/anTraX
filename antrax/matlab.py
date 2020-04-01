

from os.path import isfile, isdir, join, splitext

from threading import Thread
from subprocess import Popen, DEVNULL
import queue
import io
from time import sleep
import sys
import shutil

from .utils import *


USER = os.getenv("USER")
HOME = os.getenv("HOME")

ANTRAX_USE_MCR = os.getenv('ANTRAX_USE_MCR') == 'True'
ANTRAX_PATH = os.getenv('ANTRAX_PATH')
ANTRAX_BIN_PATH = ANTRAX_PATH + '/bin/'

PLATFORM = sys.platform
MACOS = PLATFORM == 'darwin'
LINUX = PLATFORM == 'linux'

if MACOS:
    MATLAB_PLATFORM = 'maci64'
elif LINUX:
    MATLAB_PLATFORM = 'glnxa64'

if not ANTRAX_USE_MCR:

    # case we running real matlab
    import matlab.engine


# for the case of mcr, add mcr to library path
MCR = os.getenv('ANTRAX_MCR')

if LINUX:
    LDPATH = [MCR + '/runtime/glnxa64',
              MCR + '/bin/glnxa64',
              MCR + '/sys/os/glnxa64',
              MCR + '/sys/opengl/lib/glnxa64']
    LDPATH = ':'.join(LDPATH)
    os.putenv('LD_LIBRARY_PATH', LDPATH)

elif MACOS:
    LDPATH = [MCR + '/runtime/maci64',
              MCR + '/bin/maci64',
              MCR + '/sys/os/maci64']
    LDPATH = ':'.join(LDPATH)
    os.putenv('DYLD_LIBRARY_PATH', LDPATH)
else:

    # raise error
    pass


def run_mcr_function(fun, args, diary=DEVNULL):

    fun = 'antrax_' + MATLAB_PLATFORM + '_' + fun
    args = [str(a) for a in args]

    if LINUX:

        cmd = [ANTRAX_BIN_PATH + fun] + args

    elif MACOS:

        cmd = [ANTRAX_BIN_PATH + fun + '.app/Contents/MacOS/' + fun] + args

    p = Popen(cmd, stdout=diary, stderr=diary)

    # wait for completion
    p.wait()


def start_matlab():

    eng = matlab.engine.start_matlab()
    p = eng.genpath(join(ANTRAX_PATH, 'matlab'))
    eng.addpath(p, nargout=0)
    return eng


def solve_single_graph(ex, g, c, mcr=ANTRAX_USE_MCR):

    if c is None:
        report('I', 'Start ID propagation of graph ' + str(g) + ' in ' + ex.expname)
    else:
        report('I', 'Start ID propagation of colony ' + str(c) + ' graph ' + str(g) + ' in ' + ex.expname)

    if c is None:
        diaryfile = join(ex.logsdir, 'solve_matlab_' + str(g) + '.log')
    else:
        diaryfile = join(ex.logsdir, 'solve_matlab_' + str(g) + '_c_' + str(c) + '.log')


    if mcr:

        with open(diaryfile, 'w') as diary:
            run_mcr_function('solve_single_graph', [ex.expdir, g, 'trackingdirname', ex.session, 'colony', c], diary=diary)

    else:

        out = io.StringIO()
        eng = start_matlab()
        try:
            eng.solve_single_graph(ex.expdir, g, 'trackingdirname', ex.session, 'colony', c,
                                   nargout=0, stdout=out, stderr=out)
        except:
            raise
        finally:
            with open(diaryfile, 'w') as diary:
                out.seek(0)
                shutil.copyfileobj(out, diary)

        eng.quit()

    if c is None:
        report('I', 'Finished propagation of graph ' + str(g) + ' in ' + ex.expname)
    else:
        report('I', 'Finished propagation of colony ' + str(c) + ' graph ' + str(g) + ' in ' + ex.expname)


def track_single_movie(ex, m, mcr=ANTRAX_USE_MCR):

    report('I', 'Start tracking of movie ' + str(m) + ' in ' + ex.expname)

    diaryfile = join(ex.logsdir, 'track_matlab_' + str(m) + '.log')

    if mcr:

        with open(diaryfile, 'w') as diary:
            run_mcr_function('track_single_movie', [ex.expdir, m, 'trackingdirname', ex.session], diary=diary)

    else:

        out = io.StringIO()
        eng = start_matlab()
        try:

            eng.track_single_movie(ex.expdir, m, 'trackingdirname', ex.session,
                                   nargout=0, stdout=out, stderr=out)
        except:
            raise
        finally:
            with open(diaryfile, 'w') as diary:
                out.seek(0)
                shutil.copyfileobj(out, diary)

        eng.quit()

    report('I', 'Finished tracking of movie ' + str(m) + ' in ' + ex.expname)


def link_across_movies(ex, mcr=ANTRAX_USE_MCR):

    report('I', 'Running cross movie link function for ' + ex.expname)

    if mcr:
        run_mcr_function('link_across_movies', [ex.expdir, 'trackingdirname', ex.session])
    else:
        eng = start_matlab()
        eng.link_across_movies(ex.expdir, 'trackingdirname', ex.session, nargout=0)

    report('I', 'Finished')


def launch_matlab_app(appname, args, mcr=ANTRAX_USE_MCR):

    eng = start_matlab()
    args = ['"' + a + '"' if type(a) is str else str(a) for a in args]
    app = eval('eng.' + appname + '(' + ','.join([str(a) for a in args]) + ')')
    while eng.isvalid(app, ):
        sleep(0.25)

    eng.quit()


class MatlabQueue(queue.Queue):

    def __init__(self, nw=None, mcr=ANTRAX_USE_MCR):

        super().__init__()
        self.threads = []
        self.nw = nw
        self.mcr = mcr
        if nw is not None:
            self.start_workers()

    def worker(self):

        while True:
            item = self.get()
            if item is None:
                break
            eval(item[0])(*item[1:], mcr=self.mcr)
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

