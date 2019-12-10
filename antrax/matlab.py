

from os.path import isfile, isdir, join, splitext

from threading import Thread
import queue
import io
from time import sleep

from .utils import *


USER = os.getenv("USER")
HOME = os.getenv("HOME")

ANTRAX_USE_MCR = os.getenv('ANTRAX_USE_MCR')
ANTRAX_MCR = os.getenv('ANTRAX_MCR')
ANTRAX_PATH = os.getenv('ANTRAX_PATH')

if not ANTRAX_USE_MCR:

    import matlab.engine


def start_matlab():

    eng = matlab.engine.start_matlab()
    p = eng.genpath(join(ANTRAX_PATH, 'matlab'))
    eng.addpath(p, nargout=0)
    return eng


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

