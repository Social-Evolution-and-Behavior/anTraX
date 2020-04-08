import os
from os.path import join, isdir, isfile
from glob import glob
from clize import run
from threading import Thread
from shutil import copyfile, copy, rmtree
from subprocess import Popen


def reorg(expdir, targetdir, new_expname=None, *, missing=False, force=False):

    expname = [x for x in expdir.split('/') if len(x) > 0][-1]

    if new_expname is None:
        new_expname = expname	

    new_expdir = join(targetdir, new_expname)

    if isdir(new_expdir) and force and not missing:
        print('expdir exist in location - removing')
        rmtree(new_expdir)
    elif isdir(new_expdir) and not missing:
        print('expdir exist in location - use "--force" to remove or "--missing" to only convert new files')
        return

    if not isdir(new_expdir):
        os.makedirs(new_expdir, exist_ok=True)
    else:
        print('New expdir exists')

    if not isdir(join(new_expdir, 'videos')):
        os.makedirs(join(new_expdir, 'videos'), exist_ok=True)
    else:
        print('New videos dir exists')
    
    # copy exp files
    files = glob(expdir+'/*.*')
    for x in files:
        if ~isfile(x):
            copy(x, new_expdir)
    
    # get subdir list
    viddir = join(expdir, 'videos') if isdir(join(expdir, 'videos')) else expdir
    subdirnames = [x.split('/')[-2] for x in glob(viddir+'/*/') if '_' in x.split('/')[-2]]
    subdirnames = [x for x in subdirnames if len(glob(viddir+'/' + x + '/*.avi') + glob(viddir + '/' + x + '/*.mp4')) > 0]

    # make subdirs in new expdir
    [os.makedirs(join(new_expdir + '/videos', x), exist_ok=True) for x in subdirnames if not isdir(join(new_expdir + '/videos', x))]
    
    # create a list of videos with new locations    
    videos = glob(viddir+'/*/*.avi')
    thermal = [x for x in videos if 'thermal' in x]
    videos = [x for x in videos if 'thermal' not in x]
    names = [x.split('/')[-1] for x in videos]
    paths = ['/'.join(x.split('/')[:-1]) for x in videos]

    new_paths = [x.replace(viddir, new_expdir+'/videos/') for x in paths]
    new_names = [x.replace(expname, new_expname).replace('.avi', '.mp4') for x in names]
    new_videos = [join(x, y) for x, y in zip(new_paths, new_names)]
    
    # copy thermal as is
    for v in thermal:
        x = v.replace(expdir, new_expdir + '/videos/')
        if not isfile(x):
            copyfile(v, x)

    # loop on videos 
    for v, newv in zip(videos, new_videos):
        do_one_video(v, newv)

    
def do_one_video(vid, new_vid):

    # get dat file
    dat = vid.replace('.avi', '.dat')
    new_dat = new_vid.replace('.mp4', '.dat')    
    
    # compress the video to the new location
    if not isfile(new_vid):
        cmd = 'ffmpeg -loglevel error  -i ' + vid + ' -vcodec libx264 -preset veryslow -crf 30 ' + new_vid
        p = Popen(cmd, shell=True)
        p.wait()
        print('finished transforming ' + vid.split('/')[-1])
    else:
        print('skipping ' + vid.split('/')[-1])

    # resave dat to new location
    if isfile(dat) and not isfile(new_dat):
        copyfile(dat, new_dat)
    
    
def get_file_list(root, ext):

    L = [y for x in os.walk(root) for y in glob(os.path.join(x[0], '*.'+ext))]
    return L    


if __name__ == '__main__':

    run(reorg)

