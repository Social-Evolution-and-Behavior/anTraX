
import os
import pandas as pd
from os.path import isfile, isdir, join, splitext
from itertools import count, groupby, chain
from glob import glob
import ruamel.yaml
import h5py 
import numpy as np
from threading import Thread
import queue
import io
import time

from numpy import pi
import skvideo.io as skv

USER = os.getenv("USER")
HOME = os.getenv("HOME")

MCR = os.getenv('MCR')
ANTRAX = os.getenv('ANTRAX')


class ANTRAXError(Exception):

    def __init__(self, msg):
        print(msg)


def rename_expdir(expdir, new_expname):

    expname = expdir.split('/')[-1]
    new_expdir = expdir.replace(expname, new_expname)
    os.rename(expdir, new_expdir)

    files = glob(new_expdir + '/*/*.*') + glob(new_expdir + '/*/*/*.*')
    new_files = [x.replace(expname, new_expname) for x in files]

    for f, new_f in zip(files, new_files):
        os.rename(f, new_f)


def mkdir(d):

    os.makedirs(d, exist_ok=True)


def parse_range(r):

    if len(r) == 0:
        return []
    parts = r.split("-")
    return range(int(parts[0]), int(parts[-1]) + 1)


def parse_movlist_str(arg):

    if arg is None:
        return None
    elif isinstance(arg, int) or isinstance(arg, float):
        return [arg]
    elif isinstance(arg, list):
        return arg
    elif arg == 'all':
        return None
    elif isinstance(arg, str):
        return sorted(set(chain.from_iterable(map(parse_range, arg.split(",")))))
    else:
        print('Cannot parse movlist')
        return None


def movlist2str(L):

    G = (list(x) for _, x in groupby(L, lambda x, c=count(): next(c) - x))
    S = ",".join("-".join(map(str, (g[0], g[-1])[:len(g)])) for g in G)
    return S


def is_expdir(d):

    return len(glob(d + '/*/parameters/Trck.mat')) > 0


def parse_tracklet_name(tracklet):
    
    pass


def find_expdirs(root):

    expdirs = []
    for d in glob(root):
         expdirs += [x[0] for x in os.walk(d) if is_expdir(x[0])]

    return expdirs


def load_dlc_cfg(cfg):

    yaml = ruamel.yaml.YAML()

    with open(cfg) as fp:
        d = yaml.load(fp)

    return d


def update_dlc_project_path(cfg):

    yaml = ruamel.yaml.YAML()

    with open(cfg) as fp:
        d = yaml.load(fp)

    p = os.path.dirname(cfg)

    if p != d['project_path']:
        d['project_path'] = os.path.dirname(cfg)
        with open(cfg, 'w') as fp:
            yaml.dump(d, fp)

            
def get_dlc_data_from_file(filename):
        
        f = h5py.File(filename, 'r')
        tracklets = [k for k in f.keys()]
        data = {}
        for tracklet in tracklets:
            data[tracklet] = pd.read_hdf(filename, key=tracklet)
            
        return data

    
def make_white_bg(ims):
    
    gry = np.tile(np.expand_dims(ims.max(axis=3), -1), (1, 1, 1, 3))
    bg = np.ones_like(gry) * 255
    return np.where(gry == 0, bg, ims)


def angle(x1,y1,x2,y2):
    dx = x2 - x1
    dy = y2 - y1
    return np.arctan2(dx, dy)


def to_angle(x, per=2*np.pi):
    return (x + per/2) % per - per/2


def tracklet_table_to_blob_table(tracklet_table):

    blob_table = []
    for t, trow in tracklet_table.iterrows():
        trow['tracklet'] = t
        frames = np.arange(trow['from'], trow['to']+1)
        ix = frames - trow['from']
        btable = pd.concat([trow.copy() for _ in range(trow['from'], trow['to']+1)], axis=1).T
        btable['ix'] = ix
        blob_table.append(btable)

    blob_table = pd.concat(blob_table, axis=0, ignore_index=True)
    #blob_table = blob_table.set_index(['tracklet', 'ix'])

    return blob_table

def start_matlab():

    import matlab.engine

    eng = matlab.engine.start_matlab()
    p = eng.genpath(join(ANTRAX, 'matlab'))
    eng.addpath(p, nargout=0)

    # add antrax to search path
    return eng

class MatlabQueue(queue.Queue):

    def __init__(self, nw=None):

        super().__init__()
        self.threads = []
        self.nw = nw
        if nw is not None:
            self.start_workers()

    def add_track_task(self, ex, m):

        self.put(('track', ex, m))

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

