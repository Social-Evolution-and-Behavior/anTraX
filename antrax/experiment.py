
import numpy as np
from os.path import isfile, isdir, join, splitext
import os
from glob import glob
import json
import pandas as pd
from pymatreader import read_mat
import csv
import h5py

from .utils import *
from .analysis_functions import *

class axExperiment:

    def __init__(self, expdir, session=None, expinfo={}):

        if not isdir(expdir):
            raise ANTRAXError('Given expdir ' + expdir + ' doesnt exist')
        
        self.expdir = expdir
        self.expname = expdir.rstrip('/').split('/')[-1]
        self.expinfo = expinfo
        self.alt_expname = self.expname
        if 'temperature' in self.expdir:
            self.alt_expname = os.path.abspath(self.expdir).split('/')[-3]

        self.viddir = join(self.expdir, 'videos') if isdir(join(self.expdir, 'videos')) else self.expdir

        self.subdirs = self.get_subdirs()
        self.movlist = self.get_movlist()

        if session is not None:
            self.session = session
            if not isdir(join(expdir, session)):
                print('Session ' + session + 'does not exist in experiment')
        else:
            self.session = self.get_latest_session()

        self.sessiondir = join(self.expdir, self.session)
        self.imagedir = join(self.sessiondir, 'images')
        self.trackletdir = join(self.sessiondir, 'tracklets')
        self.labelsdir = join(self.sessiondir, 'labels')
        self.paramsdir = join(self.sessiondir, 'parameters')
        self.antdatadir = join(self.sessiondir, 'antdata')
        self.prmtrs = self.get_prmtrs()
        self.movies_info = self.get_movies_info()
        
        self.antlist = self.get_labels()['ant_labels']

        self.slurmdir = join(expdir, 'slurm')
        mkdir(self.slurmdir)

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

        if ftype == 'graph':
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
        elif ftype == 'autoids' or ftype == 'autoid':
            files = glob(join(self.sessiondir, 'labels/autoids*.csv'))
            a = [int(x.split('/')[-1].split('.csv')[0].split('_')[-1]) for x in files]
        elif ftype == 'xy':
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

    def get_latest_session(self):

        sdirs = sorted(glob(self.expdir + '/*/parameters/Trck.mat'), key=os.path.getmtime)
        session = sdirs[-1].replace(self.expdir, '').replace('parameters/Trck.mat', '').replace('/', '')
        return session

    def get_movies_info(self):

        info_file = join(self.paramsdir, 'movies_info.txt')
        movies_info = pd.read_csv(info_file,sep=' ')
        return movies_info
    
    def get_f(self, m, mf):
        
        return self.movies_info['fi'][m-1] + mf - 1
    
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
        
        return vidfile(m)
    
    def datfile(self, m):
        d = join(self.viddir, self.movies_info.subdir.values[self.movies_info['index']==m][0])
        f = join(d, self.movies_info.datfile.values[self.movies_info['index']==m][0])
        return f
    
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

    def get_graph_groups(self):

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

    def get_images(self, movlist=None, tracklets=None, parts=None, bg='w'):

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
        for tracklet, ims in images.items():
            if ims.ndim==3:
                ims = np.expand_dims(ims, 0)
            ims = np.moveaxis(ims, -1, 0) 
            if bg == 'w':
                ims = make_white_bg(ims)

        return images
    
    def get_tracklet_images(self, tracklet, bg='w'):
        
        m = int(tracklet.split('_')[2][2:])
        
        file = join(self.imagedir, 'images_' + str(m) + '.mat')

        ims = read_mat(file, variable_names=[tracklet])
        ims = ims[tracklet]
        if ims.ndim==3:
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
        

class axAntData:
    
    def __init__(self, ex, movlist=None, antlist=None):

        self.ex = ex
        self.data = None

        if movlist is None:
            self.movlist = ex.movlist
        else:
            self.movlist = movlist

        if antlist is None:
            self.antlist = ex.antlist
        else:
            self.antlist = antlist

        self.load()

    def load(self):

        mdfs = []

        for m in self.movlist:

            filename = join(self.ex.antdatadir, 'xy_' + str(m) + '_' + str(m) + '.mat')
            antdata = read_mat(filename)

            # convert to dataframe
            dfs = []
            for ant in antdata.keys():
                cols = pd.MultiIndex.from_tuples([(ant, 'x'), (ant, 'y'), (ant, 'or')])
                dfs.append(pd.DataFrame(antdata[ant], columns=cols))
            df = pd.concat(dfs, axis=1)
            df['frame'] = np.arange(self.ex.movies_info.iloc[m - 1]['fi'], self.ex.movies_info.iloc[m - 1]['ff'] + 1)
            df = df.set_index('frame')
            mdfs.append(df)

        self.data = pd.concat(mdfs, axis=0)
        
    def set_v(self):
        
        for ant in self.antlist:
            dx = self.data[ant]['x'].diff()
            dy = self.data[ant]['y'].diff()
            self.data[(ant,'v')] = np.sqrt(dx**2 + dy**2)
            
    def set_nest(self, window=None, thresh = (0.5, 0.005)):
        
        idx = pd.IndexSlice
        
        # nest is defined as the median location of all ants (interpolate over missing values)
        
        self.data[('nest','x')] = self.data.loc[:,idx[:,'x']].interpolate(limit_area='inside').median(axis=1)
        self.data[('nest','y')] = self.data.loc[:,idx[:,'y']].interpolate(limit_area='inside').median(axis=1)
        
        # median smoothing for consistency
        
        if window is not None:
            
            self.data[('nest','x')] = self.data[('nest','x')].rolling(window, center=True).median()
            self.data[('nest','y')] = self.data[('nest','y')].rolling(window, center=True).median()
        
        
        for ant in self.antlist:
            dx = self.data[ant]['x'] - self.data['nest']['x']
            dy = self.data[ant]['y'] - self.data['nest']['y']
            self.data[(ant,'dnest')] = np.sqrt(dx**2 + dy**2)
            
        for ant in self.antlist:
            self.data[(ant,'outside')] = self.data[(ant,'dnest')] > thresh[1]
            
        self.data[('nest','valid')] =  self.data.loc[:,idx[:,'outside']].mean(axis=1) <= thresh[0]
        
    def set_on_edge(self, dthresh = 0.002):
        
        pass
        
        
    
    def set_interacting(self, dthresh=0.002):
        
        idx = pd.IndexSlice
        
        # define interacting as being close to other ant while outside the nest
        
        for ant in self.antlist:
            otherants = [x for x in self.antlist if not x==ant]
            out = self.data[ant]['outside'].apply(lambda x: np.where(x, x, np.nan))
            dx = self.data.loc[:,idx[otherants ,'x']].subtract(self.data[ant]['x'],axis=0).droplevel(axis=1,level=1)
            dy = self.data.loc[:,idx[otherants ,'y']].subtract(self.data[ant]['y'],axis=0).droplevel(axis=1,level=1)
            d = np.sqrt(dx**2 + dy**2) 
            self.data[(ant,'interacting')] = (d.min(axis=1) < dthresh) * out
            
    def set_stops(self, vthresh=0.0005):
        
        idx = pd.IndexSlice
        fps = self.ex.movies_info['fps'][0]
        
        out = self.data.loc[:,idx[:,'outside']].droplevel(axis=1,level=1).apply(lambda x: x.where(x, np.nan))
        v = self.data.loc[:,idx[:,'v']].droplevel(axis=1,level=1).copy()
        v = (v * out).rolling(fps).mean()
                
        for ant in self.antlist:
            
            self.data[(ant,'stop')] = v[ant] < vthresh
            
    
    def set_kinematics(self, dt=0.1):
        
        idx = pd.IndexSlice
        fps = self.ex.movies_info['fps'][0]
        
        for ant in self.antlist:
            df = trajectory_kinematics(self.data[ant], dt=1/fps)
            self.data[(ant,'curvature')] = df['curvature']
            self.data[(ant,'acceleration')] = df['a']
            self.data[(ant,'normal_acceleration')] = df['an']
            
    def head(self):
        
        self.data.head()
        
class axTrackletData:

    def __init__(self, file):

        self.data = None
        self.file = file
        self.experiment = None
        self.expdir = None
        self.session = None
        self.m = None


    def load_data(self):

        pass


