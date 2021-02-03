

from os.path import isfile, isdir, join, splitext

from threading import Thread
from subprocess import Popen, DEVNULL, STDOUT, PIPE
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
JAABA_PATH = os.getenv('ANTRAX_JAABA_PATH')
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
if ANTRAX_USE_MCR:
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


def run_matlab_function(fun, args, diaryfile=None, mcr=ANTRAX_USE_MCR, eng=None):

    close_when_done = False

    if mcr:
        with open(diaryfile, 'w') as diary:
            run_mcr_function(fun, args, diary=diary)
    else:
        out = io.StringIO()
        # start worker
        if eng is None:
            eng = start_matlab()
            close_when_done = True

        f = eval('eng.' + fun)
        # run function
        try:
            f(*args, nargout=0, stdout=out, stderr=out)
        except:
            pass
        finally:
            with open(diaryfile, 'w') as diary:
                out.seek(0)
                shutil.copyfileobj(out, diary)

        # close worker
        if close_when_done:
            eng.quit()


def run_mcr_function(fun, args, diary=DEVNULL):

    wrapper = 'antrax_' + MATLAB_PLATFORM + '_mcr_interface'
    args = [fun] + [str(a) for a in args]

    if LINUX:

        cmd = [ANTRAX_BIN_PATH + wrapper] + args

    elif MACOS:

        cmd = [ANTRAX_BIN_PATH + wrapper + '.app/Contents/MacOS/' + wrapper] + args

    report('D', 'running matlab mcr ')
    report('D', 'command is: ' + ' '.join(cmd))

    with Popen(cmd, stdout=diary, stderr=diary) as p:
        if diary == PIPE:
            while True:
                outline = p.stdout.readline().decode()
                if outline == '' and p.poll() is not None:
                    break
                if outline:
                    print(outline.strip())
            while True:
                errline = p.stderr.readline().decode()
                if errline == '' and p.poll() is not None:
                    break
                if errline:
                    print(errline.strip())
        rc = p.poll()
        report('D', 'matlab app exited with code ' + str(rc))


def start_matlab():

    eng = matlab.engine.start_matlab()
    p = eng.genpath(join(ANTRAX_PATH, 'matlab'))
    eng.addpath(p, nargout=0)
    return eng


def compile_antrax_executables():

    eng = start_matlab()
    p = eng.genpath(ANTRAX_PATH + '/matlab')
    eng.addpath(p, nargout=0)
    eng.cd(ANTRAX_PATH + '/matlab/external/popenmatlab', nargout=0)
    eng.mex('popenr.c', nargout=0)
    eng.cd(ANTRAX_PATH, nargout=0)
    eng.compile_antrax_executables(nargout=0)
    eng.quit()


def compile_mex():

    try:
        eng = start_matlab()
        eng.cd(ANTRAX_PATH + '/matlab/external/popenmatlab', nargout=0)
        eng.mex('popenr.c', nargout=0)
        eng.quit()
    except:
        print('Failed compiling mex, probably no matlab is installed')


def pair_search(ex, m, mcr=ANTRAX_USE_MCR):

    report('I', 'Running pair search for movie ' + str(m) + ' in ' + ex.expname)

    diaryfile = join(ex.logsdir, 'pair_search_matlab_' + str(m) + '.log')

    if mcr:

        with open(diaryfile, 'w') as diary:
            run_mcr_function('pair_search_single_movie', [ex.expdir, m, 'trackingdirname', ex.session], diary=diary)

    else:

        out = io.StringIO()
        eng = start_matlab()
        try:

            eng.pair_search_single_movie(ex.expdir, m, 'trackingdirname', ex.session,
                                   nargout=0, stdout=out, stderr=out)
        except:
            raise
        finally:
            with open(diaryfile, 'w') as diary:
                out.seek(0)
                shutil.copyfileobj(out, diary)

        eng.quit()

    report('I', 'Finished pair search for movie ' + str(m) + ' in ' + ex.expname)


def launch_matlab_app(appname, args, mcr=ANTRAX_USE_MCR):

    if mcr:

        run_mcr_function(appname, args, diary=PIPE)

    else:

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

        eng = start_matlab() if not self.mcr else None

        while True:
            w = self.get()
            if w is None:
                break
            report('I', 'Started ' + w['str'])
            run_matlab_function(w['fun'], w['args'], mcr=self.mcr, eng=eng, diaryfile=w['diary'])
            report('I', 'Finished ' + w['str'])
            #eval(item[0])(*item[1:], mcr=self.mcr)
            self.task_done()

        if eng is not None:
            eng.quit()

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

