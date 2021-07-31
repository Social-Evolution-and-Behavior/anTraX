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

idx = pd.IndexSlice


class axAntData:
    
    def __init__(self, ex, movlist=None, fi=None, ff=None, antlist=None, dlc=False, dlcproject=None, **kwargs):

        self.ex = ex
        self.data = None
        self.tracklet_table = None
        
        if movlist is None and fi is None:
            self.movlist = ex.movlist
            self.fi = ex.fi
            self.ff = ex.ff
        elif fi is not None and ff is not None:
            self.fi = fi
            self.ff = ff
        elif movlist is not None:
            self.movlist = movlist
            self.fi = ex.movies_info[np.isin(ex.movies_info['index'], movlist)]['fi'].min()
            self.ff = ex.movies_info[np.isin(ex.movies_info['index'], movlist)]['ff'].max()
        else:
            report('E', 'Something wrong with range arguments')
            return

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


            if antdata[self.antlist[0]].shape[1] == 3:
                with_type = False
            elif antdata[self.antlist[0]].shape[1] == 4:
                with_type = True
            else:
                report('E', 'Something wrong with antdata structure')
                return

            # convert to dataframe
            dfs = []
            for ant in self.antlist:

                if with_type:
                    cols = pd.MultiIndex.from_tuples([(ant, 'x'), (ant, 'y'), (ant, 'or'), (ant, 'ass_type')], names=['ant', 'feature'])
                else:
                    cols = pd.MultiIndex.from_tuples([(ant, 'x'), (ant, 'y'), (ant, 'or')], names=['ant', 'feature'])

                dfs.append(pd.DataFrame(antdata[ant], columns=cols))

            df = pd.concat(dfs, axis=1)
            df['frame'] = np.arange(self.ex.movies_info.iloc[m - 1]['fi'], self.ex.movies_info.iloc[m - 1]['ff'] + 1)
            df['m'] = m
            df['mf'] = np.arange(1, self.ex.movies_info.iloc[m - 1]['nframes'] + 1)
            df = df.set_index('frame')

            mdfs.append(df)

        self.data = pd.concat(mdfs, axis=0)
        self.tracklet_table = self.ex.get_tracklet_table(self.movlist)

    def set_v(self):
        
        for ant in self.antlist:
            dx = self.data[ant]['x'].diff()
            dy = self.data[ant]['y'].diff()
            self.data[(ant, 'v')] = np.sqrt(dx**2 + dy**2)
            
    def get_image(self, ant, f):
        
        # which tracklet
        ant_tracklet_table = self.tracklet_table[self.tracklet_table['ant']==ant]
        cond = (ant_tracklet_table['from'] <= f) & (ant_tracklet_table['to'] >= f)
        if not cond.sum() == 1:
            return None
        row = ant_tracklet_table[cond]
        if not row['single'].values[0]:
            return None
        
        # load tracklet images
        tracklet = row.index.tolist()[0]
        images = self.ex.get_images(movlist=row['m'], tracklets=[tracklet])[tracklet]
        ix = f - row['from']
        im = np.squeeze(images[ix])
        return im

        # return image
            
    def set_nest(self, window=None, thresh=(0.5, 0.005)):
        
        idx = pd.IndexSlice
        
        # nest is defined as the median location of all ants (interpolate over missing values)
        
        self.data[('nest', 'x')] = self.data.loc[:, idx[:, 'x']].interpolate(limit_area='inside').median(axis=1)
        self.data[('nest', 'y')] = self.data.loc[:, idx[:, 'y']].interpolate(limit_area='inside').median(axis=1)
        
        # median smoothing for consistency
        
        if window is not None:
            
            self.data[('nest', 'x')] = self.data[('nest', 'x')].rolling(window, center=True).median()
            self.data[('nest', 'y')] = self.data[('nest', 'y')].rolling(window, center=True).median()

        for ant in self.antlist:
            dx = self.data[ant]['x'] - self.data['nest']['x']
            dy = self.data[ant]['y'] - self.data['nest']['y']
            self.data[(ant, 'dnest')] = np.sqrt(dx**2 + dy**2)
            
        for ant in self.antlist:
            self.data[(ant, 'outside')] = self.data[(ant, 'dnest')] > thresh[1]
            
        self.data[('nest', 'valid')] = self.data.loc[:, idx[:, 'outside']].mean(axis=1) <= thresh[0]
        
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
        
        fps = self.ex.movies_info['fps'][0]
        
        for ant in self.antlist:
            df = trajectory_kinematics(self.data[ant], dt=1/fps)
            self.data[(ant,'velocity')] = df['v']
            self.data[(ant,'curvature')] = df['curvature']
            self.data[(ant,'acceleration')] = df['a']
            self.data[(ant,'normal_acceleration')] = df['an']

    def set_trdata(self, fields=None):
        
        for m in self.movlist:
            
            trdata = read_mat(join(self.ex.trackletdir,'trdata_' + str(m) + '.mat')) 

    def set_dlc(self, dlcproject=None):

        if dlcproject is None:
            
            dlcproject = self.ex.get_dlc_project()
            
        if dlcproject is None:
            
            print('No DeepLabCut run results were found in session')
            return
            
        dlcdir = self.ex.get_dlc_dir(dlcproject)
        
        for m in self.movlist:
            
            dlcdata = get_dlc_data_from_file(join(dlcdir, 'predictions_' + str(m) + '.h5'))
            trdata = read_mat(join(self.ex.trackletdir,'trdata_' + str(m) + '.mat')) 
            
            for ant in self.antlist:
                
                ant_tracklet_table = self.tracklet_table[self.tracklet_table['ant']==ant]
                ant_tracklets = [t for t in ant_tracklet_table.index.tolist() if t in dlcdata]  
                ant_dlcdata = {t:dlcdata[t] for t in ant_tracklets}
                fi = {t:ant_tracklet_table.at[t,'from'] for t in ant_tracklets}
                ff = {t:ant_tracklet_table.at[t,'to'] for t in ant_tracklets}
                
                for t, df in ant_dlcdata.items():
                    df['frame'] = range(fi[t], ff[t]+1)
                    df = df.set_index('frame', drop=True)
                    mi = pd.MultiIndex.from_tuples([(ant, x[1] + '_' + x[2]) for x in df.columns.to_list()], names=['ant', 'feature'])
                    df.columns = mi
                    if trdata[t].ndim == 1:
                        trdata[t] = trdata[t][None,:]
                    df[ant, 'bbx0'] = trdata[t][:,7]
                    df[ant, 'bby0'] = trdata[t][:,8]
                    ant_dlcdata[t] = df
                    
                if len(ant_dlcdata)>0:
                    ant_dlcdata = pd.concat(ant_dlcdata.values())
                    self.data = self.data.combine_first(ant_dlcdata)
                    
        self.data = self.data.reindex(columns=sorted(self.data.columns))
    
    def set_antpower(self, window=51):
        
        for ant in self.antlist:

            antdata = self.data.loc[:,idx[ant,:]].droplevel(axis=1,level=0)
            
            box_head_angle = angle(antdata['Head_x'],antdata['Head_y'],antdata['Neck_x'],antdata['Neck_y'])
            box_r_ant_angle = angle(antdata['R_ant_tip_x'],antdata['R_ant_tip_y'],antdata['R_ant_root_x'],antdata['R_ant_root_y'])
            box_l_ant_angle = angle(antdata['L_ant_tip_x'],antdata['L_ant_tip_y'],antdata['L_ant_root_x'],antdata['L_ant_root_y'])
    
            head_r_ant_angle = to_angle(box_r_ant_angle - box_head_angle, per=np.pi)
            head_l_ant_angle = to_angle(box_l_ant_angle - box_head_angle, per=np.pi)
            rl_ant_angle = to_angle(box_l_ant_angle - box_r_ant_angle, per=np.pi)
            self.data[ant, 'r_ant_angle'] =  head_r_ant_angle
            self.data[ant, 'l_ant_angle'] =  head_l_ant_angle
            self.data[ant, 'antpower'] = (head_r_ant_angle.diff()**2 + head_l_ant_angle.diff()**2).rolling(51, center=True).mean()
            self.data[ant, 'antcoherence'] = (rl_ant_angle.diff() ** 2).rolling(51, center=True).mean()

    def set_jaaba(self, behaviors=None):

        jdir = self.ex.sessiondir + '/jaaba/'

        scorefiles = glob(jdir + '/scores_*.csv')
        bs = [s.split('.csv')[0].split('scores_')[-1].split('_')[0] for s in scorefiles]
        bs = set(bs)

        if behaviors is not None:
            behaviors = [b for b in bs if b in behaviors]
        else:
            behaviors = bs

        # init
        for b in behaviors:

            for ant in self.antlist:
                self.data[ant, 'scores_' + b] = None

        # assign
        for m in self.movlist:

            fi = self.ex.movies_info.iloc[m - 1]['fi']
            ff = self.ex.movies_info.iloc[m - 1]['ff']

            for b in behaviors:

                sf = jdir + 'scores_' + b + '_' + str(m) + '.csv'

                try:
                    scores = pd.read_csv(sf)
                except:
                    continue


                scores['frame'] = np.arange(fi, ff + 1)
                scores = scores.set_index('frame')

                for ant in self.antlist:

                    self.data.loc[fi:ff, idx[ant, 'scores_' + b]] = scores[ant].values.copy()

        self.data = self.data.reindex(columns=sorted(self.data.columns))


    def get_features(self, n=25, cols=['v','antpower']):
        
        import pywt
        
        idx = pd.IndexSlice
        
        df = []
        
        for ant in self.antlist:
            x = self.data.loc[:,idx[ant,cols]].values
            x = wavelet_expansion(x, n=n, maxscale=50)
            mi = pd.MultiIndex.from_tuples([(ant,i) for i in range(x.shape[1])], names=['ant','feature'])
            df.append(pd.DataFrame(x, index=self.data.index, columns=mi))
        
        df = pd.concat(df, axis=1)
        
        return df
            
    def head(self):
        
        return self.data.head()


class axTrackletData:

    def __init__(self, ex, movlist=None, verbose=False, nants=None):

        self.ex = ex
        self.trdata = None
        self.tracklet_table = None
        self.movlist = movlist

        if movlist is None:
            self.movlist = ex.movlist
        else:
            self.movlist = movlist

        if nants is None and ex.prmtrs['tagged']:
            nants = len(ex.antlist)
        elif nants is None:
            nants = ex.nants

        self.nants = nants

        self.load(verbose=verbose)

        self.groupByFrame = self.trdata.groupby(by='frame', axis=0)
        #self.groupByTracklet = self.trdata.groupby(by='tracklet', axis=0)

    def load(self, verbose=False):

        mdfs = []

        for m in self.movlist:

            if verbose:
                report('I', 'Loading data of movie ' + str(m))

            try:
                filename = join(self.ex.antdatadir, 'xy_' + str(m) + '_' + str(m) + '_untagged.h5')
                df = pd.read_hdf(filename, key='trdata')
                #df = self.ex.get_tracklet_data(only_ants=True, only_singles=False, movlist=self.movlist)
            except:
                report('W', 'Could not load xy file for video ' + str(m))
                column_names = ['tracklet', 'frame', 'frameix', 'x', 'y', 'majax', 'eccentricity', 'area', 'or', 'bbx0', 'bby0', 'autoid', 'single', 'm']
                df = pd.DataFrame(columns=column_names)
                df.set_index(['tracklet', 'frame', 'frameix'], drop=False, inplace=True, verify_integrity=True)

            df.rename_axis(['tracklet', 'f', 'frameix'], axis='index', inplace=True)


            # df.drop('tracklet', axis=1, inplace=True)

            # if not self.ex.is_parted(m):
            #     filename = join(self.ex.antdatadir, 'xy_' + str(m) + '_' + str(m) + '_untagged.mat')
            #     tracklet_data = read_mat(filename)
            # else:
            #    parts = self.ex.get_parts(m)
            #    trdata = [read_mat(join(self.ex.antdatadir, 'xy_' + str(m) + '_p' + str(p) + '.mat')) for p in parts]
            #    trdata = {k: v for d in trdata for k, v in d.items()}

            # convert to dataframe

            # cols = ['tracklet', 'frame', 'x', 'y', 'orient', 'area', 'nants']
            # if 'majax' in tracklet_data:
            #    cols.append('majax')

            # cols = pd.Index(cols)

            # d = {k: tracklet_data[k] for k in cols if k in tracklet_data.keys()}
            # d['x'] = tracklet_data['xy'][:, 0]
            # d['y'] = tracklet_data['xy'][:, 1]

            # df = pd.DataFrame(d)


            # have no idea what this is for, commenting it temporarilly 23/7/2021
            #df['tracklet'] = df['tracklet'].astype('int')

            df['m'] = m
            df['frame'] = df['frame'].astype('int')

            mdfs.append(df)

        self.trdata = pd.concat(mdfs, axis=0)

        if 'majorax' in self.trdata:
            self.trdata.rename(columns={'majorax': 'majax'}, inplace=True)

        try:
            self.tracklet_table = self.ex.get_tracklet_table(self.movlist, type='untagged')
        except:
            report('W', 'Could not read tracklet table ')
