

import scipy
import scipy.signal
from multiprocessing.pool import ThreadPool
import pandas as pd
import numpy as np
from numpy import pi
from skimage.draw import circle_perimeter, circle, line, line_aa
from PIL import Image
from os.path import join, isdir, isfile
import os


from .utils import *
from .data import axAntData, axTrackletData
from .analysis_functions import *



### cli functions ###


def compute_medians(ex, movlist=None):

    report('I', 'Computing medians for movie ' + str(movlist))

    if movlist is None:
        movlist = ex.movlist

    td = axTempData(ex, movlist=movlist)
    td.compute_medians()
    td.save_frmdata()


def compute_nest_location(ex, movlist=None, K=36001):

    report('I', 'Computing nest location for experiment ' + ex.expname)

    if movlist is None:
        movlist = ex.movlist
    report('I', '   ...Loading')
    td = axTempData(ex, movlist=movlist)
    report('I', '   ...Computing')
    td.nest_median_filtering(K=K)
    report('I', '   ...Saving')
    td.save_frmdata()


def compute_measures(ex, movlist=None):

    report('I', 'Computing measures for movie ' + str(movlist))

    if movlist is None:
        movlist = ex.movlist

    td = axTempData(ex, movlist=movlist)
    td.compute_measures()
    td.save_frmdata()


def exportxy_untagged(ex, movlist=None, missing=False):

    report('I', 'Exporting xy for movie ' + str(movlist))

    if movlist is None:
        movlist = ex.movlist

    if missing:
        movlist = [m for m in ex.get_missing(ftype='xy_untagged_h5') if m in movlist]

    for m in movlist:
        ex.export_xy_untagged_one_movie(m)

    report('I', 'Finished exporting xy for movie ' + str(movlist))


#### aux functions for pandas apply ####


def perframe_collective_measures_untagged(X, frmdata):
    # this will calculate behavioral measures per frame
    frame = X.name

    nestx = frmdata.at[frame, 'nestx']
    nesty = frmdata.at[frame, 'nesty']
    nestr = frmdata.at[frame, 'nestr']

    d = {}

    dnest = np.sqrt((X['x'] - nestx) ** 2 + (X['y'] - nesty) ** 2)
    outside = dnest > nestr
    if np.count_nonzero(outside) == 0:
        d['nout'] = [0]
        d['fracout'] = [0]
        d['vout'] = [np.nan]
    elif np.count_nonzero(outside & X['single']) == 0:
        d['nout'] = [X['nants'].loc[outside].values.sum()]
        d['fracout'] = [X['w'].loc[outside].values.sum()]
        d['vout'] = [np.nan]
    else:
        d['vout'] = [X['v'].loc[outside & X['single']].values.mean()]
        d['nout'] = [X['nants'].loc[outside].values.sum()]
        d['fracout'] = [X['w'].loc[outside].values.sum()]

    df = pd.DataFrame.from_dict(d)
    return df


####

def load_frmdata(ex, movlist=None):

    if movlist is None:
        movlist = ex.movlist

    frmdatadir = join(ex.sessiondir, 'frmdata')
    frmdata = []

    for m in movlist:
        filename = join(frmdatadir, 'frmdata_' + str(m) + '.csv')
        frmdata.append(pd.read_csv(filename))

    frmdata = pd.concat(frmdata, axis=0)
    frmdata = frmdata.set_index('framenum')

    return frmdata


def save_frmdata(ex, frmdata):

    frmdatadir = join(ex.sessiondir, 'frmdata')

    movlist = set([ex.get_m_mf(f)[0] for f in frmdata['frame']])

    for m in movlist:

        filename = join(frmdatadir, 'frmdata_' + str(m) + '.csv')

        fi = ex.movies_info[ex.movies_info['index'] == m]['fi'].values[0]
        ff = ex.movies_info[ex.movies_info['index'] == m]['ff'].values[0]

        rows = (frmdata.index >= fi) & (frmdata.index <= ff)
        fd = frmdata[rows]
        fd.to_csv(filename)


def make_events(td, Tth=27.5, before=10*60*10, after=60*60*10, dur=15*60*10):


    ex = td.ex
    frmdata = td.frmdata

    cond = frmdata['S1'].values > Tth

    cond = np.diff(cond.astype('float'))

    events = {}

    events['onset'] = np.where(cond == 1)[0] + 1
    events['offset'] = np.where(cond == -1)[0] + 1

    # init event table
    events['exp'] = ex.expname
    events['expname'] = ex.expname
    events['nants'] = td.nants

    events['S'] = frmdata['S1'].loc[events['onset'] + 3000].values
    events['T'] = np.array([frmdata['thmean'].iloc[(i + 3000):(i + 6000)].mean() for i in events['onset']])

    # make triggered response traces
    events['nout'] = [frmdata['nout'].iloc[(i - before):(i + after)].values for i in events['onset']]
    events['vout'] = [frmdata['vout'].iloc[(i - before):(i + after)].values for i in events['onset']]
    events['TT'] = [frmdata['thcammean'].iloc[(i - before):(i + after)].values for i in
                    events['onset']]

    # calc response measures
    events['nout_max'] = np.array([np.nanmax(x[before:(before+dur)]) / td.nants for x in events['nout']])
    events['nout_mean'] = np.array([np.mean(x[before:(before+dur)]) / td.nants for x in events['nout']])
    events['nout_end'] = np.array([x[before+dur] / td.nants for x in events['nout']])
    events['vout_max'] = np.array([np.nanmax(x[before:(before+dur)]) for x in events['vout']])

    events['nout_tau'] = []

    for e in events['nout']:
        x = e[before:(before+dur)]
        th = np.nanmax(x) * (1 - np.exp(-1))
        cond = x > th
        try:
            events['nout_tau'].append(np.nanmin(np.where(cond)) / 10)
        except:
            print('Something wrong with tau calc')
            events['nout_tau'].append(np.nan)

    events['vout_tau'] = []
    for e in events['vout']:
        x = e[before:(before+dur)]
        th = np.nanmax(x) * (1 - np.exp(-1))
        cond = x > th
        try:
            events['vout_tau'].append(np.min(np.where(cond)) / 10)
        except:
            print('Something wrong with tau calc')
            events['vout_tau'].append(np.nan)

    events['T_tau'] = []
    for s, e in zip(events['S'], events['TT']):
        x = e[before:(before+dur)]
        th = s * (1 - np.exp(-1))
        cond = x > th
        try:
            events['T_tau'].append(np.min(np.where(cond)) / 10)
        except:
            print('Something wrong with tau calc')
            events['T_tau'].append(np.nan)

    # make event table
    events['nout_tau'] = np.array(events['nout_tau'])
    events['vout_tau'] = np.array(events['vout_tau'])
    events['T_tau'] = np.array(events['T_tau'])
    # events['nout'] = [list(x) for x in events['nout']]
    # events['vout'] = [list(x) for x in events['vout']]

    # self.events = events
    events = pd.DataFrame(events)
    events['exp'] = ex.expname
    events['nants'] = td.nants

    return events


class axTempData(axTrackletData):

    def __init__(self, ex, movlist=None, nants=None, verbose=False, reset_frmdata=False):

        super().__init__(ex, movlist=movlist, verbose=verbose)

        if nants is None and ex.prmtrs['tagged']:
            nants = len(ex.antlist)
        elif nants is None:
            nants = ex.nants

        self.nants = nants

        # check if frmdata files exist
        frmdatadir = join(ex.sessiondir, 'frmdata')
        mkdir(frmdatadir)

        exist_frmdata = all([isfile(join(frmdatadir, 'frmdata_' + str(m) + '.csv')) for m in self.movlist])

        self.frmdata = None

        if exist_frmdata and not reset_frmdata:
            self.load_frmdata()
        else:
            self.reset_frmdata()

    def make_events(self):

        self.events = make_events(self)

    def get_event(self, ix):

        row = self.events.iloc[ix]

    def reset_frmdata(self):

        self.frmdata = self.ex.get_dat(movlist=self.movlist)
        self.frmdata['thmean'] = self.frmdata[['T1', 'T2', 'T3', 'T4']].mean(axis=1)
        self.frmdata['thcammean'] = self.frmdata[['thcam1', 'thcam2', 'thcam3', 'thcam4']].mean(axis=1)

    def load_frmdata(self):

        self.frmdata = load_frmdata(self.ex, movlist=self.movlist)

    def save_frmdata(self):

        frmdatadir = join(self.ex.sessiondir, 'frmdata')

        for m in self.movlist:

            filename = join(frmdatadir, 'frmdata_' + str(m) + '.csv')

            fi = self.ex.movies_info[self.ex.movies_info['index'] == m]['fi'].values[0]
            ff = self.ex.movies_info[self.ex.movies_info['index'] == m]['ff'].values[0]

            rows = (self.frmdata.index >= fi) & (self.frmdata.index <= ff)
            fd = self.frmdata[rows]
            fd.to_csv(filename)

    def compute_measures(self):

        # single
        self.trdata['single'] = self.tracklet_table.iloc[self.trdata['tracklet'] - 1]['single'].values
        self.trdata['w'] = self.trdata['area'] / self.groupByFrame['area'].transform('sum')
        self.trdata['nants'] = self.nants * self.trdata['w']
        self.frmdata['total_area'] = self.groupByFrame['area'].sum()

        # velocities
        self.trdata['vx'] = self.trdata['x'].diff() * 10
        self.trdata['vx'].where(self.trdata['tracklet'] == self.trdata['tracklet'].shift(), inplace=True)
        self.trdata['vy'] = self.trdata['y'].diff() * 10
        self.trdata['vy'].where(self.trdata['tracklet'] == self.trdata['tracklet'].shift(), inplace=True)
        self.trdata['v'] = np.sqrt(self.trdata['vx'] ** 2 + self.trdata['vy'] ** 2)
        self.trdata['v'].where(self.trdata['tracklet'] == self.trdata['tracklet'].shift(), inplace=True)

        # collective measures
        self.frmdata.drop(['vout', 'nout', 'fracout'], errors='ignore', inplace=True, axis=1)
        self.frmdata = self.frmdata.join(
            self.groupByFrame.apply(perframe_collective_measures_untagged, self.frmdata).reset_index(level=1, drop=True))

    def compute_medians(self):

        # blob weight and nants estimation
        self.trdata['w'] = self.trdata['area'] / self.groupByFrame['area'].transform('sum')
        self.trdata['nants'] = self.nants * self.trdata['w']

        self.frmdata['total_area'] = self.groupByFrame['area'].sum()

        self.frmdata.drop(['medx', 'medy', 'majmax'], errors='ignore', inplace=True, axis=1)
        self.frmdata = self.frmdata.join(self.groupByFrame.apply(nest_untagged).reset_index(level=1, drop=True))
        self.frmdata['medx'] = self.frmdata['medx'].astype('float')
        self.frmdata['medy'] = self.frmdata['medy'].astype('float')
        if 'majmax' in self.frmdata:
            self.frmdata['majmax'] = self.frmdata['majmax'].astype('float') * self.ex.prmtrs['geometry_rscale']

    def nest_median_filtering(self, K=36001):

        fun = lambda xx: scipy.signal.medfilt(xx, kernel_size=K)

        x = [self.frmdata['medx'], self.frmdata['medy']]

        if 'majmax' in self.frmdata:
            x.append(self.frmdata['majmax'])
            pool = ThreadPool(3)
        else:
            pool = ThreadPool(2)

        y = pool.map(fun, x)

        pool.close()
        pool.join()

        self.frmdata['nestx'] = y[0]
        self.frmdata['nesty'] = y[1]

        if 'majmax' in self.frmdata:
            self.frmdata['nestr'] = y[2]


class axTempDataTaggged(axTempData, axAntData):

    def __init__(self, ex, movlist=None, nants=None, verbose=False, reset_frmdata=False):

        super().__init__(ex, movlist=movlist, nants=nants, verbose=verbose, reset_frmdata=reset_frmdata)


class event:

    def __init__(self, ad, f0):

        ex = ad.ex

        self.expname = ex.expname
        self.f0 = f0
        self.fi = f0 - 15*60*10
        self.ff = f0 + 75*60*10
        self.nants = ex.nants

        self.tracks = ex.get_xy()
        self.frmdata = None

