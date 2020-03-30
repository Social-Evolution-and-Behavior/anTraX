
import os
import pandas as pd
from os.path import isfile, isdir, join, splitext
from itertools import count, groupby, chain
from glob import glob
import ruamel.yaml
import h5py 
import numpy as np
from datetime import datetime

from numpy import pi
import skvideo.io as skv


import socket

HOSTNAME = socket.gethostname()
USER = os.getenv("USER")
HOME = os.getenv("HOME")

MCR = os.getenv('MCR')
ANTRAX = os.getenv('ANTRAX')


class ANTRAXError(Exception):

    def __init__(self, msg):
        print(msg)


def report(a, msg):

    a = ' -' + a + '- '
    ts = datetime.now().strftime('%d/%m/%y %H:%M:%S')
    print(ts + a + msg)


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


def classes_from_examplesdir(examplesdir):

    # how many classes in example dir?
    classes = sorted([x.split('/')[-1] for x in glob(examplesdir+'/*')])

    # exclude empty subdirectories
    classes = [x for x in classes if os.listdir(join(examplesdir, x))]

    return classes


def get_segments(x):

    ix = np.diff(x).nonzero()[0]
    start = np.concatenate(([0], ix + 1))
    end = np.concatenate((ix + 1, [x.shape[0]]))
    value = np.array([x[ixx] for ixx in start])

    return start, end, value


# Print iterations progress
def printProgressBar (iteration, total, prefix = '', suffix = '', decimals = 1, length = 100, fill = '#', printEnd = "\r"):
    """
    Call in a loop to create terminal progress bar
    @params:
        iteration   - Required  : current iteration (Int)
        total       - Required  : total iterations (Int)
        prefix      - Optional  : prefix string (Str)
        suffix      - Optional  : suffix string (Str)
        decimals    - Optional  : positive number of decimals in percent complete (Int)
        length      - Optional  : character length of bar (Int)
        fill        - Optional  : bar fill character (Str)
        printEnd    - Optional  : end character (e.g. "\r", "\r\n") (Str)
    """
    percent = ("{0:." + str(decimals) + "f}").format(100 * (iteration / float(total)))
    filledLength = int(length * iteration // total)
    bar = fill * filledLength + '-' * (length - filledLength)
    print('\r%s |%s| %s%% %s' % (prefix, bar, percent, suffix), end = printEnd)
    # Print New Line on Complete
    if iteration == total:
        print()