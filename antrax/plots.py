

import numpy as np
from matplotlib import pyplot as plt
import matplotlib.colors as mcolors

import seaborn


def plot_trajectories_together(antdata):

    pass


def plot_trajectories(antdata):

    pass


def plot_activity(antdata):

    pass

def heatmaps(antdata, cmap='terrain'):
    
    fig, axs = prepare_axes(antdata)
    ants, colors = parse_ants(antdata)
    
    for i, c1 in enumerate(colors):
        
        for j, c2 in enumerate(colors):
            
            ant = c1 + c2
            xbb = antdata[ant]['x'][~np.isnan(antdata[ant]['x'])];
            ybb = antdata[ant]['y'][~np.isnan(antdata[ant]['x'])];
            axs[i,j].hist2d(xbb,ybb,100,norm=mcolors.LogNorm(), cmap=cmap);
            
    

def prepare_axes(antdata, figsize=(16,16)):
    
    
    cmap = {'B':'b','G':'g','O':'orange','P':'magenta'}
    
    ants, colors = parse_ants(antdata)
    n = len(colors)
    
    fig, axs = plt.subplots(n, n, figsize=figsize)
    
    for ant, ax1 in zip(ants, axs.flatten()):
        ax1.axis('off')
        
        
        c1 = ant[0]
        c2 = ant[1]
        circle1 = plt.Circle((0, 0.06), 0.005, color=cmap[c1], clip_on=False)
        circle2 = plt.Circle((0, 0.055), 0.005, color=cmap[c2], clip_on=False)
        ax1.add_artist(circle1)
        ax1.add_artist(circle2)
    
    return fig, axs


def parse_ants(antdata):
    
    ants = list(antdata.columns.levels[0].values[:-1])
    colors = set(''.join(ants))
    
    return ants, colors
