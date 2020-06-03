import os
from os.path import join, isdir, isfile
from glob import glob
from clize import run
from threading import Thread
from shutil import copyfile, copy, rmtree, copytree
from subprocess import Popen, PIPE
import queue
import time
import antrax as ax


def reorg(expdir, targetdir, *, new_expname=None, missing=False, force=False, tracking=False, nw=1, hpc=False):

    expname = [x for x in expdir.split('/') if len(x) > 0][-1]

    if new_expname is None:
        new_expname = expname	

    new_expdir = join(targetdir, new_expname)

    if isdir(new_expdir) and force and not missing:
        ax.report('W', 'expdir exist in location - removing')
        rmtree(new_expdir)
    elif isdir(new_expdir) and not missing:
        ax.report('E', 'expdir exist in location - use "--force" to remove or "--missing" to only convert new files')
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

    new_paths = [x.replace(viddir, new_expdir + '/videos/') for x in paths]
    new_names = [x.replace(expname, new_expname).replace('.avi', '.mp4') for x in names]
    new_videos = [join(x, y) for x, y in zip(new_paths, new_names)]

    ax.report('I', 'Found ' + str(len(new_videos)) + ' videos to convert')

    # copy thermal as is
    if len(thermal) > 0:
        ax.report('I', 'Copying thermal camera videos')
    for v in thermal:
        x = v.replace(expdir, new_expdir + '/videos/')
        if not isfile(x):
            copyfile(v, x)

    # copy dat files
    ax.report('I', 'Copying dat files')
    for v, vnew in zip(videos, new_videos):
        dat = v[:-3] + 'dat'
        new_dat = vnew[:-3] + 'dat'
        if isfile(dat) and not isfile(new_dat):
            copyfile(dat, new_dat)

    if not hpc:

        q = queue.Queue()

        for v, newv in zip(videos, new_videos):
            w = {'vid': v, 'new_vid': newv}
            q.put_nowait(w)

        for _ in range(nw):
            Worker(q).start()

        q.join()  # blocks until the queue is empty.

    else:

        # create job file

        jobfile = join(new_expdir, 'antrax_reorg.sh')
        with open(jobfile, 'w') as f:

            in_array_line = 'VIN=(' + ' '.join(['"' + v + '"' for v in videos]) + ')'
            out_array_line = 'VOUT=(' + ' '.join(['"' + v + '"' for v in new_videos]) + ')'

            cmd = 'ffmpeg -loglevel error  -i ${VIN[$SLURM_ARRAY_TASK_ID]} -vcodec libx264 -preset veryslow -crf 30 ${VOUT[$SLURM_ARRAY_TASK_ID]}'

            f.writelines("#!/bin/bash\n")
            f.writelines("#SBATCH --job-name=%s\n" % 'reorg')
            f.writelines("#SBATCH --output=%s_%%a.log\n" % join(new_expdir, 'antrax_reorg.log'))
            f.writelines("#SBATCH --ntasks=%d\n" % 1)
            f.writelines("#SBATCH --cpus-per-task=%d\n" % 8)
            f.writelines("#SBATCH --array=%d-%d%%%d\n" % (0, len(new_videos)-1, 100))
            f.writelines("\n")
            f.writelines(in_array_line + '\n\n')
            f.writelines(out_array_line + '\n\n')
            f.writelines("srun -N1 %s\n" % cmd)

        p = Popen("sbatch %s" % jobfile, stdout=PIPE, shell=True)
        (out, err) = p.communicate()
        out = out.decode("utf-8")
        jid = out.split()[-1]
        ax.report('I', 'Submitted job ' + str(jid))

    # copy tracking sessions
    if tracking:
        if not ax.is_expdir(expdir):
            ax.report('I', 'No antrax sessions found')
        else:
            ex = ax.axExperiment(expdir)
            sessions = ex.get_sessions()
            for s in sessions:
                ax.report('I', 'Copying antrax session ' + s)
                copytree(join(expdir, s), new_expdir)


class Worker(Thread):

    def __init__(self, q, *args, **kwargs):

        self.q = q
        super().__init__(*args, **kwargs)

    def run(self):

        while True:

            try:

                w = self.q.get(timeout=3)  # 3s timeout

            except queue.Empty:

                return

            # compress the video to the new location
            if not isfile(w['new_vid']):
                cmd = 'ffmpeg -loglevel error  -i ' + w['vid'] + ' -vcodec libx264 -preset veryslow -crf 30 ' + w['new_vid']
                p = Popen(cmd, shell=True)
                p.wait()
                ax.report('I', 'Finished trancoding ' + w['new_vid'].split('/')[-1])
            else:
                ax.report('I', 'Skipping ' + w['new_vid'].split('/')[-1])

            self.q.task_done()


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

