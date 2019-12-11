

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

ANTRAX_USE_MCR = os.getenv('ANTRAX_USE_MCR')
ANTRAX_PATH = os.getenv('ANTRAX_PATH')
ANTRAX_BIN_PATH = ANTRAX_PATH + '/bin/'

PLATFORM = sys.platform

MACOS = PLATFORM == 'darwin'
LINUX = PLATFORM == 'linux'



if not ANTRAX_USE_MCR:

    # case we running real matlab
    import matlab.engine

else:

    # for the case of mcr, add mcr to library path
    MCR = os.getenv('ANTRAX_MCR')

    if LINUX:
        LDPATH = [MCR + '/runtime/glnx64',
                  MCR + '/bin/glnx64',
                  MCR + '/sys/os/glnx64',
                  MCR + '/sys/opengl/lib/glnx64']
        LDPATH = ':'.join(LDPATH)
        os.environ['LD_LIBRARY_PATH'] == LDPATH

    elif MACOS:
        LDPATH = [MCR + '/runtime/maci64',
                  MCR + '/bin/maci64',
                  MCR + '/sys/os/maci64']
        LDPATH = ':'.join(LDPATH)
        os.environ['DYLD_LIBRARY_PATH'] == LDPATH
    else:

        # raise error
        pass


def run_mcr_function(fun, args, diary=DEVNULL):

    if LINUX:

        cmd = ANTRAX_BIN_PATH + fun + ' ' + ' '.join(args)

    elif MACOS:

        cmd = ANTRAX_BIN_PATH + fun + '.app/Contents/MacOS/' + fun + ' ' + ' '.join(args)

    p = Popen(cmd, stdout=diary, stderr=diary)

    # wait for completion
    p.wait()


def start_matlab():

    eng = matlab.engine.start_matlab()
    p = eng.genpath(join(ANTRAX_PATH, 'matlab'))
    eng.addpath(p, nargout=0)
    return eng


def track_single_movie(ex, m):

    print('Start tracking of movie ' + str(m) + ' in ' + ex.expname)

    diaryfile = join(ex.logsdir, 'track_' + str(m) + '.log')

    if ANTRAX_USE_MCR:
        with open(diaryfile) as diary:
            run_mcr_function('track_single_movie', ['trackingdirname', ex.session, 'm', m], diary=diary)

    else:
        out = io.StringIO()
        eng = start_matlab()
        eng.track_single_movie(ex.expdir, 'trackingdirname', ex.session, 'm', m, 'diary', diaryfile, nargout=0,
                               stdout=out, stderr=out)

        with open(diaryfile) as diary:
            out.seek(0)
            shutil.copyfileobj(out, diary)

    print('Finished tracking of movie ' + str(m) + ' in ' + ex.expname)


def launch_antrax_app():

    eng = start_matlab()
    app = eng.antrax()
    while eng.isvalid(app, ):
        sleep(0.25)


class MatlabQueue(queue.Queue):

    def __init__(self, nw=None):

        super().__init__()
        self.threads = []
        self.nw = nw
        if nw is not None:
            self.start_workers()

    def add_track_task(self, ex, m):

        self.put(('track', ex, m))

    def add_solve_task(self, ex, g):

        pass

    def add_task(self, fun, args):

        self.put((fun, args))

    def worker(self):

        # start matlab engine
        if not ANTRAX_USE_MCR:
            eng = start_matlab()

        while True:
            out = io.StringIO()
            err = io.StringIO()
            item = self.get()
            if item is None:
                break
            if item[0] == 'track':
                ex = item[1]
                m = item[2]
                diaryfile = join(ex.logsdir, 'track_' + str(m) + '.log')
                print('Start tracking of movie ' + str(m) + ' in ' + ex.expname)

                eng.track_single_movie(ex.expdir, 'trackingdirname', ex.session, 'm', m, 'diary', diaryfile, nargout=0,
                                       stdout=out, stderr=err)
                print('Finished tracking of movie ' + str(m) + ' in ' + ex.expname)
            elif item[0] == 'solve':
                pass
            else:
                print('Start ', item[0])
                fun = eval('eng.' + item[0])
                fun(*item[1], nargout=0, stdout=out, stderr=err)
                print('Finished ', item[0])
            self.task_done()

        eng.quit()

    def start_workers(self):

        threads = []

        print('Starting ' + str(self.nw) + ' matlab workers')
        for i in range(self.nw):
            t = Thread(target=self.worker)
            t.start()
            threads.append(t)

        self.threads = threads

    def stop_workers(self, wait=True):

        for i in range(self.nw):
            self.put(None)

        if wait:
            self.join()

