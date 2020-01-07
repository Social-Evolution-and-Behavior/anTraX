
from tempfile import mkdtemp
import numpy as np
import skvideo.io as skv
from skimage.io import imsave
import shutil
import os
from os.path import isfile, isdir
from glob import glob
import pandas as pd

from .utils import *
from .experiment import *

idx = pd.IndexSlice


import deeplabcut as dlc


def process_images(images):

    # expand dims if needed
    if images.ndim == 3:
        images = images[None, :, :, :]

    # make gray scale
    # images = images.astype('float') / 255
    gry = np.repeat(images.min(axis=3, keepdims=True), 3, axis=3)

    # make white background
    images[gry == 0] = 255

    # increase contrast
    # images = images / 0.6 - 1 / 6
    # images = np.clip(images, 0, 1)

    # make rgb
    #images = 255 * np.repeat(images, 3, axis=3)
    #images = images.astype('uint8')

    return images


def create_trainset(ex, projdir, n=100, antlist=None, movlist=None, vid=True):

    if antlist is None:
        antlist = ex.antlist

    if vid:
        viddir = ex.sessiondir + '/videos4dlc/'
        mkdir(viddir)

    if isfile(projdir):
        pathlist = os.path.normpath(projdir).split(os.path.sep)
        projdir = os.path.sep.join(pathlist[:-1])

    # get tracklet table
    tracklet_table = ex.get_tracklet_table(movlist)

    # filter single ant tracklets
    tracklet_table = tracklet_table[tracklet_table['single'] == 1]

    # examples per ant:
    na = int(n/len(antlist)) + 1

    # init vidlist
    vidlist = []

    for ant in antlist:

        if vid:

            vidname = viddir + ex.expname + '_' + ant + '.mp4'

            if isfile(vidname):
                k = 1
                while isfile(vidname):
                    vidname = viddir + ex.expname + '_' + ant + '_' + str(k) + '.mp4'
                    k += 1

            writer = skv.FFmpegWriter(vidname)
        else:
            framedir = projdir + '/labeled-data/' + ex.expname + '_' + ant
            if not isdir(framedir):
                mkdir(framedir)
                cnt = 1
            else:
                files = glob(framedir + '/img*.png')
                cnt = 1 + max([int(os.path.basename(x)[3:-4]) for x in files])


        ttable = tracklet_table[tracklet_table['ant'] == ant]
        btable = tracklet_table_to_blob_table(ttable)
        btable = btable.sample(na)
        ts = set(btable['tracklet'].values)
        ms = set(btable['m'].values)
        images = ex.get_images(movlist=ms, tracklets=ts)

        for t, ims in images.items():

            ix = btable.loc[btable['tracklet'] == t, 'ix'].values

            for ixx in ix:
                if vid:
                    writer.writeFrame(ims[ixx])
                else:
                    fname = join(framedir, 'img{0:03d}.png'.format(cnt))
                    imsave(fname, ims[ixx])
                    cnt += 1
        if vid:
            vidlist.append(vidname)
            writer.close()

    return vidlist


def images2avi(images, vidfile):

    # save video
    skv.vwrite(vidfile, images, inputdict={'-vcodec': 'rawvideo', '-pix_fmt': 'rgb24'},
               outputdict={'-vcodec': 'rawvideo', '-pix_fmt': 'rgb24'})


def images2avidir(images, viddir):

    for i, (k, ims) in enumerate(images.items()):

        ims = process_images(ims)

        vidfile = join(viddir, k + '.avi')
        images2avi(ims, vidfile)


def predict_images(images, dlccfg, dbfile):

    viddir = mkdtemp()
    try:
        print('Writing temp video files in dir ' + viddir)
        images2avidir(images, viddir)
        print('Finished video writing')
    except:
        shutil.rmtree(viddir)
        print('Failed video writing')
        raise

    destdir = mkdtemp()
    try:
        print('Running DLC. Results will be stored in ' + destdir)
        dlc.analyze_videos(dlccfg, [viddir], destfolder=destdir)
        print('Finished DLC run')
    except:
        shutil.rmtree(viddir)
        shutil.rmtree(destdir)
        print('DLC failed')
        raise

    print('Storing prediction in ' + dbfile)

    try:
        for tracklet in images.keys():
            h5file = sorted(glob(join(destdir, tracklet) + '*.h5'), key=os.path.getmtime)[-1]
            df = pd.read_hdf(h5file)
            df.to_hdf(dbfile, key=tracklet, mode='a')
    except:
        shutil.rmtree(viddir)
        shutil.rmtree(destdir)
        print('Failed storing results')
        raise

    # clean
    print('Cleaning up')
    shutil.rmtree(destdir)
    shutil.rmtree(viddir)


def dlc4antrax(expdir, dlccfg, *, session=None, movlist=None, ntracklets=None):

    if not isinstance(expdir, axExperiment):

        ex = axExperiment(expdir, session=session)

    else:

        ex = expdir
        expdir = ex.expdir


    update_dlc_project_path(dlccfg)
    dlc_dict = load_dlc_cfg(dlccfg)
    dlc_project_name = dlc_dict['Task']

    dest_folder = join(ex.sessiondir, 'deeplabcut-' + dlc_project_name)
    mkdir(dest_folder)

    if movlist is None:
        movlist = ex.movlist
    else:
        movlist = parse_movlist_str(movlist)

    if ntracklets is not None:
        ntracklets = int(ntracklets)

    for m in movlist:

        # load images
        parted = ex.is_parted(m)

        if parted:
            for p in ex.get_parts(m):
                print('Loading images for movie ' + str(m) + ' part ' + str(p))
                images = ex.get_images(m, p, ntracklets=ntracklets)
                dbfile = join(ex.sessiondir, 'deeplabcut-' + dlc_project_name + '/predictions_' + str(m) + '_p' + str(p) + '.h5')
                predict_images(images, dlccfg, dbfile)
        else:
            print('Loading images for movie ' + str(m))
            images = ex.get_images(m, ntracklets=ntracklets)
            dbfile = join(ex.sessiondir, 'deeplabcut-' + dlc_project_name + '/predictions_' + str(m) + '.h5')
            predict_images(images, dlccfg, dbfile)

