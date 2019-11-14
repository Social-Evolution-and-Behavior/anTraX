
from tempfile import mkdtemp
import numpy as np
import deeplabcut as dlc
import skvideo.io as skv
import shutil
import os
from glob import glob
import pandas as pd

from .utils import *
from .experiment import *


def images2avi(images, vidfile):

    # expand dims if needed
    if images.ndim == 3:
        images = images[None, :, :, :]

    images = images.astype('float') / 255
    images = images.min(axis=3, keepdims=True)

    images[images == 0] = 255

    images = images / 0.6 - 1 / 6
    images = np.clip(images, 0, 1)
    images = 255 * np.repeat(images, 3, axis=3)
    images = images.astype('uint8')

    # save video
    skv.vwrite(vidfile, images, inputdict={'-vcodec': 'rawvideo', '-pix_fmt': 'rgb24'},
               outputdict={'-vcodec': 'rawvideo', '-pix_fmt': 'rgb24'})


def images2avidir(images, viddir):

    for i, (k, ims) in enumerate(images.items()):

        vidfile = join(viddir, k + '.avi')
        images2avi(ims, vidfile)


def predict_images(images, dlccfg, dbfile):

    ok = True
    viddir = mkdtemp()

    print('Writing temp video files in dir ' + viddir)

    try:
        images2avidir(images, viddir)
    except:
        ok = False
        print('Failed video writing')

    print('Finished video writing')

    destdir = mkdtemp()
    print('Running DLC. Results will be stored in ' + destdir)

    if ok:
        try:
            dlc.analyze_videos(dlccfg, [viddir], destfolder=destdir)
        except:
            ok = False
            print('DLC failed')

    print('Finished DLC run')

    print('Storing prediction in ' + dbfile)

    if ok:
        try:
            for tracklet in images.keys():
                h5file = sorted(glob(join(destdir, tracklet) + '*.h5'), key=os.path.getmtime)[-1]
                df = pd.read_hdf(h5file)
                df.to_hdf(dbfile, key=tracklet, mode='a')
        except:
            ok = False
            print('Failed storing results')

    # clean
    print('Cleaning up')
    shutil.rmtree(destdir)
    shutil.rmtree(viddir)
    if ok:
        print('Finished!')
    else:
        print('Failed :-((((')


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

