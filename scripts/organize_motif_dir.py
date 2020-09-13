import numpy as np
from glob import glob
import os
from os.path import join, isdir, isfile, dirname
from shutil import copyfile
from antrax.utils import mkdir, report
from clize import run
import yaml
import pandas as pd


def motif_org(d, *, outdir=None, subdir_dur=24, expname=None, remove=False):

    if expname is None or outdir is None:
        expname = dirname(d).split('/')[-1]
    if outdir is None:
        expdir = d
    else:
        expdir = join(outdir, expname)

    mkdir(expdir)
    viddir = join(expdir, 'videos')
    mkdir(viddir)

    # list all video files

    vid_files = glob(join(d, '*mp4'))
    vidix = np.array([int(f.split('/')[-1].split('.')[0]) for f in vid_files])
    vidix = vidix - vidix.min() + 1
    vidix, vid_files = zip(*sorted(zip(vidix, vid_files)))

    npz_files = [x.replace('mp4', 'npz') for x in vid_files]
    frame_numbers = [np.load(x)['frame_number'] for x in npz_files]
    frame_times = [np.load(x)['frame_time'] for x in npz_files]

    dt = [np.diff(x) for x in frame_times]

    for i, x in enumerate(frame_times):
        if i > 0:
            dt[i] = [frame_times[i][0] - frame_times[i-1][-1]] + list(dt[i])
        else:
            dt[i] = [dt[i][0]] + list(dt[i])

    nframes = [len(x) for x in frame_numbers]

    vidinfo = pd.DataFrame({'vid': vid_files, 'npz': npz_files, 'framenum': frame_numbers, 'timestamp': frame_times})

    vidinfo['ix'] = vidix
    vidinfo['dt'] = dt

    yfile = join(d, 'metadata.yaml')

    with open(yfile) as f:
        metadata = yaml.load(f, Loader=yaml.FullLoader)

    framerate = metadata['acquisitionframerate']

    frames_per_subdir = framerate * 3600 * subdir_dur
    frames_per_file = metadata['__store']['chunksize']
    files_per_subdir = frames_per_subdir/frames_per_file
    num_subdirs = int(np.ceil(vidinfo['ix'].max()/files_per_subdir))

    subdirs = []
    for i in range(num_subdirs):
        mi = int(i*files_per_subdir + 1)
        mf = min(int((i+1)*files_per_subdir), vidinfo['ix'].max())
        sd = join(viddir, str(mi) + '_' + str(mf))
        subdirs.append(sd)
        mkdir(sd)

    for i, row in vidinfo.iterrows():

        subdir = subdirs[int(np.floor(row['ix']/files_per_subdir))]
        copyfile(row['vid'], join(subdir, str(expname) + '_' + str(row['ix']) + '.mp4'))

        dat = pd.DataFrame({'% framenum': row['framenum'], 'timestamp': row['timestamp'], 'dt': row['dt']})
        dat.to_csv(join(subdir, str(expname) + '_' + str(row['ix']) + '.dat'), sep='\t', index=False)

    if not expdir == d:
        copyfile(yfile, join(expdir, 'metadata.yaml'))

    if remove:
        report('I', 'Removing original files')
        for f in vid_files + npz_files:
            os.remove(f)


if __name__ == '__main__':

    run(motif_org)
