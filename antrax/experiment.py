
import numpy as np
from os.path import isfile, isdir, join, splitext
import os
from glob import glob
import matplotlib.image as mpimg
import json
import pandas as pd
from pymatreader import read_mat
import csv
import h5py
import skvideo.io

from .utils import *
from .analysis_functions import *

from .data import *

class axExperiment:

    def __init__(self, expdir, session=None, expinfo={}):

        if not isdir(expdir):
            raise ANTRAXError('Given expdir ' + expdir + ' doesnt exist')
        
        self.expdir = expdir
        self.expname = expdir.rstrip('/').split('/')[-1]
        self.expinfo = expinfo

        if session is not None:
            self.session = session
            if not isdir(join(expdir, session)):
                print('Session ' + session + 'does not exist in experiment')
                return
        else:
            self.session = self.get_latest_session()

        self.sessiondir = join(self.expdir, self.session)
        self.imagedir = join(self.sessiondir, 'images')
        self.trackletdir = join(self.sessiondir, 'tracklets')
        self.labelsdir = join(self.sessiondir, 'labels')
        self.paramsdir = join(self.sessiondir, 'parameters')
        self.antdatadir = join(self.sessiondir, 'antdata')
        self.logsdir = join(self.sessiondir, 'logs')
        self.prmtrs = self.get_prmtrs()
        self.movies_info = self.get_movies_info()
        self.job_table_file = self.sessiondir + '/.antrax_job_table.csv'

        self.alt_expname = self.expname

        if 'temperature' in self.expdir:
            self.alt_expname = os.path.abspath(self.expdir).split('/')[-3]

        self.viddir = join(self.expdir, 'videos') if isdir(join(self.expdir, 'videos')) else self.expdir

        self.subdirs = self.get_subdirs()
        self.movlist = self.get_movlist()
        self.glist, self.ggroups = self.get_glist()
        if 'geometry_colony_labels' in self.prmtrs.keys():
            self.clist = list(range(1, len(self.prmtrs['geometry_colony_labels'])+1))
            self.colony_labels = self.prmtrs['geometry_colony_labels']
        else:
            self.clist = [1]
            self.colony_labels = []

        if 'tagged' in self.prmtrs:
            if self.prmtrs['tagged']:
                self.antlist = self.get_labels()['ant_labels']
            else:
                self.antlist = []
        else:
            try:
                self.antlist = self.get_labels()['ant_labels']
            except:
                self.antlist = []

        try:
            mkdir(self.logsdir)
        except:
            report('W', 'Could not create directories')

    def get_subdirs(self):

        subdirs = glob(self.viddir + '/*_*')
        subdirs = [x for x in subdirs if len(glob(x + '/*mp4') + glob(x + '/*avi')) > 0]
        subdirs = [x.split('/')[-1] for x in subdirs]

        return subdirs

    def get_movlist(self):

        vids = glob(self.viddir + '/*_*/*.mp4') + glob(self.viddir + '/*_*/*.avi')
        movlist = sorted([int(splitext(x)[0].split('_')[-1]) for x in vids if 'thermal' not in x])
        return movlist

    def get_file_list(self, ftype='video'):

        if ftype == 'graph' or ftype == 'track':
            files = glob(join(self.sessiondir, 'graphs/graph*.mat')) + glob(join(self.sessiondir, 'graphs/*/graph*.mat'))
            files = [x for x in files if 'trjs' not in x]
            files = [x for x in files if '_p' not in x]
            a = [int(x.split('/')[-1].split('.mat')[0].split('_')[-1]) for x in files]
            a = list(set(a))
        elif ftype == 'images':
            files = glob(join(self.sessiondir, 'images/image*.mat'))
            files = [x for x in files if '_p' not in x]
            a = [int(x.split('/')[-1].split('.mat')[0].split('_')[-1]) for x in files]
            a = list(set(a))
        elif ftype == 'autoids' or ftype == 'autoid' or ftype == 'classify':
            files = glob(join(self.sessiondir, 'labels/autoids*.csv'))
            a = [int(x.split('/')[-1].split('.csv')[0].split('_')[-1]) for x in files]
        elif ftype == 'xy' or ftype == 'solve':
            files = glob(join(self.sessiondir, 'antdata/xy*.mat')) + glob(join(self.sessiondir, 'antdata/*/xy*.mat'))
            files = [x for x in files if '_p' not in x]
            a = [int(x.split('/')[-1].split('.mat')[0].split('_')[-1]) for x in files]
            a = list(set(a))
        elif ftype == 'exit' or ftype == 'exits':
            files = glob(join(self.sessiondir, 'antdata/exit*.mat')) + glob(join(self.sessiondir, 'antdata/*/exit*.mat'))
            files = [x for x in files if '_p' not in x]
            a = [int(x.split('/')[-1].split('.mat')[0].split('_')[-1]) for x in files]
            a = list(set(a))
        elif ftype == 'predictions' or ftype == 'dlc':
            files = glob(join(self.sessiondir, 'deeplabcut*/predictions*.h5'))
            a = [int(x.split('/')[-1].split('.h5')[0].split('_')[-1]) for x in files]
            a = list(set(a))
        else:
            print('Something wrong')
            a = []

        return a

    def get_sessions(self):

        sdirs = sorted(glob(self.expdir + '/*/parameters/Trck.mat'), key=os.path.getmtime)
        sessions = [sd.replace(self.expdir, '').replace('parameters/Trck.mat', '').replace('/', '') for sd in sdirs]

        return sessions

    def get_latest_session(self):

        sdirs = sorted(glob(self.expdir + '/*/parameters/Trck.mat'), key=os.path.getmtime)
        session = sdirs[-1].replace(self.expdir, '').replace('parameters/Trck.mat', '').replace('/', '')
        return session

    def get_movies_info(self):

        info_file = join(self.paramsdir, 'movies_info.txt')
        movies_info = pd.read_csv(info_file, sep=' ')
        return movies_info
    
    def get_f(self, m, mf):
        
        return self.movies_info['fi'][m-1] + mf - 1

    def get_m_mf(self, f):

        cond = (self.movies_info['fi'] <= f) & (self.movies_info['ff'] >= f)
        m = self.movies_info[cond]['index'].values[0]
        mf = f - self.movies_info[cond]['fi'].values[0] + 1

        return m, mf

    
    def parse_tracklet_name(self, tracklet):
        
        m = int(tracklet.split('_')[2][2:])
        mfi = int(tracklet.split('_')[3])
        mff = int(tracklet.split('_')[5])
        
        fi = self.get_f(m, mfi)
        ff = self.get_f(m, mff)
        
        return fi, ff
    
    def vidfile(self, m):
        
        d = join(self.viddir, self.movies_info.subdir.values[self.movies_info['index']==m][0])
        f = join(d, self.movies_info.movfile.values[self.movies_info['index']==m][0])
        return f
    
    def movfile(self, m):
        
        return self.vidfile(m)
    
    def datfile(self, m):
        d = join(self.viddir, self.movies_info.subdir.values[self.movies_info['index']==m][0])
        f = join(d, self.movies_info.datfile.values[self.movies_info['index']==m][0])
        return f

    def get_frame(self, m):

        vidfile = self.vidfile(m)
        frame = skvideo.io.vread(vidfile, num_frames=1)
        return np.squeeze(frame)

    
    def get_dat(self, flds=None, movlist=None):
        
        if movlist is None:
            movlist = self.movlist
            
        dats = [pd.read_csv(self.datfile(m), sep="\t") for m in movlist]
        dat = pd.concat(dats, ignore_index=False)
        
        dat = dat.rename(columns={'% framenum':'framenum'})
        dat = dat.set_index('framenum')
        return dat

    def get_prmtrs(self):

        params_file = join(self.paramsdir, 'prmtrs.json')
        prmtrs = {}
        if isfile(params_file):
            with open(params_file, 'r') as f:
                try:
                    prmtrs = json.load(f)
                except:
                    print('-W- something wrong with prmtrs.json')

        return prmtrs

    def get_labels(self):

        labelsfile = join(self.paramsdir, 'labels.csv')
        self.labels = {}

        # old format
        if isfile(join(self.paramsdir, 'labels.mat')):
            #print('Old label format')
            with open(labelsfile) as f:
                reader = csv.reader(f)
                for row in reader:
                    self.labels[row[0]] = row[1:]

        # new format
        else:
            with open(labelsfile) as f:
                reader = csv.reader(f, delimiter='\t')
                for row in reader:
                    if row[1] not in self.labels:
                        self.labels[row[1]] = []
                    self.labels[row[1]] += [row[0]]

        # hack
        if 'nonant_labels' in self.labels and 'noant_labels' not in self.labels:
            self.labels['noant_labels'] = self.labels['nonant_labels']
            del self.labels['nonant_labels']

        return self.labels

    def get_bg(self):

        bgfile = join(self.paramsdir, 'backgrounds/background.png')
        bg = mpimg.imread(bgfile)

        return bg

    def get_glist(self):

        if 'graph_groupby' not in self.prmtrs:

            self.prmtrs['graph_groupby'] = 'subdir'

        if self.prmtrs['graph_groupby'] in ['experiment', 'wholeexperiment']:

            glist = [1]
            ggroups = self.movlist

        elif self.prmtrs['graph_groupby'] in ['subdir', 'subdirs']:

            glist = [g+1 for g in range(len(self.subdirs))]
            ggroups = [list(range(int(x.split('_')[0]), int(x.split('_')[1]) + 1)) for x in self.subdirs]
            ggroups = [[x for x in g if x in self.movlist] for g in ggroups]

        elif self.prmtrs['graph_groupby'] in ['movie']:

            glist = [i+1 for i, m in enumerate(self.movlist)]
            ggroups = [[m] for m in self.movlist]

        elif self.prmtrs['graph_groupby'] == 'custom':

            ggroups = self.prmtrs['graph_groups']
            if not isinstance(ggroups, list):
                ggroups = [ggroups]
            ggroups = [grp if isinstance(grp, list) else [grp] for grp in ggroups]
            glist = [g + 1 for g in range(len(ggroups))]

        else:

            print('Something wrong with graph lists')
            glist = []
            ggroups = []

        ggroups = [sorted(grp) for grp in ggroups]
        ggroups = [x for _,x in sorted(zip(glist, ggroups))]
        glist = sorted(glist)

        return glist, ggroups

    def get_graph_group(self, g):

        ggroups = [list(range(int(x.split('_')[0]), int(x.split('_')[1]) + 1)) for x in self.subdirs]
        ggroups = [[x for x in g if x in self.movlist] for g in ggroups]
        gfrom = [min(g) for g in ggroups]
        gto = [max(g) for g in ggroups]

        if 'graph_groups' in self.prmtrs:
            ggroups = self.prmtrs['graph_groups']
            gfrom = [min(x) for x in ggroups]
            gto = [max(x) for x in ggroups]

        return gfrom, gto

    def get_missing(self, ftype=None):

        a = self.get_movlist()
        b = self.get_file_list(ftype)
        missing = [x for x in a if x not in b]

        return missing

    def is_parted(self, m):

        return isfile(self.sessiondir + '/tracklets/trdata_' + str(m) + '_p1.mat')

    def get_parts(self, m):

        a = glob(self.sessiondir + '/tracklets/trdata_' + str(m) + '_p*.mat')
        parts = [int(x.split('_p')[1].split('.')[0]) for x in a]
        return parts

    def get_images(self, movlist=None, tracklets=None, parts=None, bg='w', ntracklets=None):

        if hasattr(movlist, '__iter__'):
            movlist = list(movlist)
        else:
            movlist = [movlist]

        images = {}

        if parts is not None:
            m = movlist[0]
            for p in parts:
                file = join(self.imagedir, 'images_' + str(m) + '_p' + str(p) + '.mat')
                imagesm = read_mat(file, variable_names=tracklets)
                images.update(imagesm)
        else:
            for m in movlist:
                file = join(self.imagedir, 'images_' + str(m) + '.mat')
                imagesm = read_mat(file, variable_names=tracklets)
                images.update(imagesm)

        # arange images
        for tracklet in images.keys():
            if images[tracklet].ndim == 3:
                images[tracklet] = np.expand_dims(images[tracklet], -1)

            images[tracklet] = np.moveaxis(images[tracklet], -1, 0)
            if bg == 'w':
                images[tracklet] = make_white_bg(images[tracklet])

        if ntracklets is not None and ntracklets < len(images):

            tracklets = list(images.keys())
            images = {tracklet: images[tracklet] for tracklet in tracklets[:ntracklets]}

        return images

    def calc_assignment_rate(self,  colonies=None, exclude_colonies=[]):

        tt = self.get_tracklet_table()

        N = self.movies_info['nframes'].sum() * len(self.antlist)
        tt['len'] = tt['to'] - tt['from'] + 1
        class_rate = tt.loc[tt['source'] == 1, :]['len'].sum()/N
        ass_rate = tt['len'].sum()/N

        print('assignment rate is ' + str(ass_rate))
        print('classification rate is ' + str(class_rate))

    def get_tracklet_table(self, movlist=None, type=None, colonies=None, exclude_colonies=[]):

        if colonies is None:
            colonies = self.colony_labels

        if len(exclude_colonies) > 0:
            colonies = [c for c in colonies if c not in exclude_colonies]

        if type is None or type == 'tagged':
            sfx = ''
        else:
            sfx = '_' + type

        if movlist is None:
            movlist = self.movlist

        tracklet_table = []

        for m in movlist:

            if self.prmtrs['geometry_multi_colony']:

                for c in colonies:
                    tracklet_table_m = pd.read_csv(
                        join(self.antdatadir, c + '/tracklets_table_' + str(m) + '_' + str(m) + sfx + '.csv'))
                    tracklet_table_m['colony'] = c
                    tracklet_table.append(tracklet_table_m)

            else:
                tracklet_table_m = pd.read_csv(
                    join(self.antdatadir, 'tracklets_table_' + str(m) + '_' + str(m) + sfx + '.csv'))

            tracklet_table.append(tracklet_table_m)



        tracklet_table = pd.concat(tracklet_table, axis=0)

        if type == 'untagged':
            tracklet_table = tracklet_table.set_index('index', drop=True)
        else:
            tracklet_table = tracklet_table.set_index('tracklet', drop=True)

        return tracklet_table
    
    def get_tracklet_images(self, tracklet, bg='w'):
        
        m = int(tracklet.split('_')[2][2:])
        
        file = join(self.imagedir, 'images_' + str(m) + '.mat')

        ims = read_mat(file, variable_names=[tracklet])
        ims = ims[tracklet]

        if ims.ndim == 3:
            ims = np.expand_dims(ims, -1)

        ims = np.moveaxis(ims, -1, 0)

        if bg == 'w':
            ims = make_white_bg(ims)
        
        return ims

    def get_ant_data(self, movlist=None, antlist=None, fields=None):

        ad = axAntData(self, movlist=movlist, antlist=antlist)
        return ad

    def get_autoids(self, movlist=None):
        
        autoids = {}
        filelist = []
        
        for m in movlist:
            parted = self.is_parted(m)
            if not parted:
                filelist.append(join(self.labelsdir, 'autoids_' + str(m) + '.csv'))
            else:
                filelist = filelist + [join(self.labelsdir, 'autoids_' + str(m) + '_p' + str(p) + '.csv') for p in self.get_parts(m)]
                    
        for f in filelist:
            ff = open(f)
            r = csv.reader(ff)
            for row in r:
                autoids[row[0]] = row[1]
                
        return autoids    
        
    def get_tracklet_data(self, movlist=None, dlc=False, dlcproject=None, only_ants=True, only_singles=False):

       
        if movlist is None:
            movlist = self.movlist
        
        trdata = []
        for m in movlist:
            trdatam = self.get_tracklet_data_one_movie(m, dlc=dlc, dlcproject=dlcproject, only_ants=only_ants, only_singles=only_singles)
            trdata.append(trdatam)
        
        # this contains the frame data
        trdata = pd.concat(trdata, ignore_index=False)
                
        return trdata 
            
    def get_tracklet_data_one_movie(self, m, dlc, dlcproject=None, only_ants=True, only_singles=False):
        
        print('Loading data for movie ' + str(m))
        
        parted = self.is_parted(m)
        dlcdir = self.get_dlc_dir(dlcproject)
        
        if not parted:
            trdata = read_mat(join(self.trackletdir,'trdata_' + str(m) + '.mat'))  
            if dlc:
                dlcdata = get_dlc_data_from_file(join(dlcdir, 'predictions_' + str(m) + '.h5'))
        else:            
            parts = self.get_parts(m)
            trdata = [read_mat(join(self.trackletdir,'trdata_' + str(m) + '_p' + str(p) + '.mat')) for p in parts]
            trdata = {k: v for d in trdata for k, v in d.items()}
            if dlc:
                dlcdata = [get_dlc_data_from_file(join(dlcdir, 'predictions_' + str(m) + '_p' + str(p) + '.h5')) for p in parts]
                dlcdata = {k: v for d in dlcdata for k, v in d.items()}
        
        
        # if dlc, filter out tracklets without predictions (i.e. not singles)
        if dlc:
            trdata = {k: v for k, v in trdata.items() if k in dlcdata.keys()}
        
        # filter by classification
        autoids = self.get_autoids([m])
        
        if only_ants:
            noant_tracklets = [k for k, v in autoids.items() if v in self.get_labels()['noant_labels']]
            trdata = {k: v for k, v in trdata.items() if k not in noant_tracklets}
            if dlc:
                dlcdata = {k: v for k, v in dlcdata.items() if k in ant_tracklets}
        
        dfs = []
        
        for tracklet, v in trdata.items():

            if v.ndim == 1:
                v = np.expand_dims(v, axis=0)
            fi, ff = self.parse_tracklet_name(tracklet)
            aid = autoids[tracklet] if tracklet in autoids.keys() else ''
            s = (aid in self.get_labels()['ant_labels'] and not aid=='MultiAnt') or (aid in self.get_labels()['other_labels'])
            index = list(range(v.shape[0]))
            data = {'tracklet': pd.Series(tracklet, index),
                    'frame': pd.Series(list(range(fi,ff+1))),
                    'frameix': pd.Series(list(range(ff-fi+1))),
                    'area': pd.Series(v[:,0]),
                    'x': pd.Series(v[:,1]),
                    'y':pd.Series(v[:,2]),
                    'majorax':pd.Series(v[:,3]),
                    'eccentricity':pd.Series(v[:,4]),
                    'bbx0':pd.Series(v[:,7]),
                    'bby0':pd.Series(v[:,8]),
                    'or': pd.Series(v[:,5]),
                    'autoid': pd.Series(aid, index),
                    'single': pd.Series(s, index)
                    }
            
            data = pd.DataFrame(data)
            data = data[['tracklet','frame','frameix','x','y','majorax','eccentricity','area','or','bbx0','bby0','autoid','single']]
            
            if only_singles:
                data = data.loc[data['single']]
            
            if dlc:
                data = pd.concat([data, dlcdata[tracklet]], axis=1, ignore_index=False)
                
            
            dfs.append(pd.DataFrame(data))
            
        df = pd.concat(dfs, ignore_index=False)
        #mix = pd.MultiIndex(df[['tracklet','frame','frameix']])
        #df.reindex(mix)
        df.set_index(['tracklet','frame','frameix'], drop=False, inplace=True, verify_integrity=True)
        
        return df
            

    def get_frame_data(self, movlist=None):

        pass
    
    def get_dlc_project(self):
        
        try:
            a = glob(self.sessiondir + '/deeplabcut*')[0].split('/')[-1]
            return a[11:]
        except:
            return None
            
        
    
    def get_dlc_dir(self, project=None):
        
        if project is None:
            project = self.get_dlc_project()
            
        if project is None:
            return None
        else:
            return join(self.sessiondir,'deeplabcut-' + project)

    def get_dlc_data(self, movlist, bodyparts=None, project=None):
                
        dlcdir = self.get_dlc_dir(project)
        data = {}
        for m in movlist:            
            dlcdata = get_dlc_data_from_file(join(dlcdir,'predictions_' + str(m) + '.h5'))
    
        return dlcdata
        


