
from subprocess import Popen, PIPE
from os.path import isdir, isfile, join
from os import remove
from glob import glob
from .utils import *

def create_slurm_job_file(opts):

    jobname = opts.get('jobname')
    filename = opts.get('filename')
    workdir = opts.get('workdir')
    cmd = opts.get('cmd')
    taskarray = opts.get('taskarray')

    ntasks = opts.get('ntasks', 1)
    cpus = opts.get('cpus', 2)
    email = opts.get('email', None)
    mailtype = opts.get('mailtype', 'ALL')
    partition = opts.get('partition', None)
    throttle = opts.get('throttle', len(taskarray))

    precmd = opts.get('precmd', [])

    jobfile = join(workdir, filename + '.sh')
    logfile = join(workdir, filename)

    with open(jobfile, 'w') as f:

        f.writelines("#!/bin/bash\n")
        f.writelines("#SBATCH --job-name=%s\n" % jobname)
        f.writelines("#SBATCH --output=%s_%%a.log\n" % logfile)
        if partition is not None:
            f.writelines("#SBATCH --partition=%s\n" % partition)
        f.writelines("#SBATCH --ntasks=%d\n" % ntasks)
        f.writelines("#SBATCH --cpus-per-task=%d\n" % int(cpus))

        if all([a in taskarray for a in range(min(taskarray), max(taskarray) + 1)]):
            f.writelines("#SBATCH --array=%d-%d%%%d\n" % (min(taskarray), max(taskarray), throttle))
        else:
            f.writelines("#SBATCH --array=%s%%%d\n" % (','.join([str(a) for a in taskarray]), throttle))

        f.writelines("#SBATCH --mail-type=%s\n" % mailtype)
        f.writelines("#SBATCH --mail-user=%s\n" % email)
        f.writelines("\n")

        for x in precmd:
            f.writelines("%s\n" % x)

        f.writelines("srun -N1 %s\n" % cmd)

    return jobfile


def submit_slurm_job_file(jobfile):

    p = Popen("sbatch %s" % jobfile, stdout=PIPE, shell=True)
    (out, err) = p.communicate()
    out = out.decode("utf-8")
    jid = out.split()[-1]

    return jid


def submit_antrax_job(jobfile):

    jid = submit_slurm_job_file(jobfile)

    print('')
    print('Job number ' + str(jid) + ' was submitted')
    print('')

    # log the job id


def prepare_antrax_job(ex, step, taskarray, opts):

    #precmd = ["cd %s\n" % antrax]
    precmd = []

    if step == 'track':
        jobname = 'trk:' + ex.expname
        jobfile = join(ex.slurmdir, 'antrax_track.sh')
        logfile = 'trk'
        opts['cpus'] = opts.get('cpus', 2)
        cmd = 'run_antrax track ' + ex.expdir + \
              ' --session ' + ex.session + \
              ' --classdir ' + opts['classdir'] + \
              ' --movlist $SLURM_ARRAY_TASK_ID'

    elif step == 'post':
        jobname = 'pst:' + ex.expname
        jobfile = join(ex.slurmdir, 'antrax_post.sh')
        logfile = 'pst'
        cpus = 2
        cmd = ''

    elif step == 'classify':
        jobname = 'cls:' + ex.expname
        jobfile = join(ex.slurmdir, 'antrax_classify.sh')
        logfile = 'cls'
        cpus = 6
        cmd = 'run_antrax classify expdir' + \
            ' --session ' + opts['session'] + \
            ' --classdir ' + opts['classdir'] + \
            ' --movlist $SLURM_ARRAY_TASK_ID'

    elif step == 'solve':
        jobname = 'slv:' + ex.expname
        jobfile = join(ex.slurmdir, 'antrax_solve.sh')
        logfile = 'slv'
        cpus = 4
        cmd = ''

    elif step == 'dlc':
        if taskarray is None:
            taskarray = ex.movlist
        opts['jobname'] = 'dlc:' + ex.expname
        opts['filename'] = 'dlc'
        opts['cpus'] = opts.get('cpus', 6)
        #precmd.append('export ')
        opts['cmd'] = 'run_antrax.py dlc ' + ex.expdir + \
            ' --session ' + ex.session + \
            ' --cfg ' + opts['cfg'] + \
            ' --movlist $SLURM_ARRAY_TASK_ID'

    else:
        return

    opts['workdir'] = ex.slurmdir
    opts['taskarray'] = taskarray
    jobfile = create_slurm_job_file(opts)

    return jobfile


def clear_tracking_data(ex, step, movlist, opts):

    # it is a good idea to clear tracking data centrally before hpc run, so we'll know which tasks failed without
    # looking at the logs

    if opts.get('dry', False):
        return

    if movlist is None:
        movlist = ex.movlist

    for m in movlist:

        if step == 'track':

            [remove(x) for x in glob(ex.sessiondir + '/*/*_' + str(m) + '.mat')]
            [remove(x) for x in glob(ex.sessiondir + '/*/*_' + str(m) + '_trjs.mat')]
            [remove(x) for x in glob(ex.sessiondir + '/labels/autoids_' + str(m) + '.csv')]

        if step == 'post':

            [remove(x) for x in glob(ex.sessiondir + '/antdata/*_' + str(m) + '.mat')]

        if step == 'classify':

            [remove(x) for x in glob(ex.sessiondir + '/labels/autoids_' + str(m) + '.csv')]

        if step == 'solve':
            pass

        if step == 'dlc':

            dlcproject = load_dlc_cfg(opts['cfg'])['Task']

            dest_folder = join(ex.sessiondir, 'deeplabcut-' + dlcproject)
            [remove(x) for x in glob(dest_folder + '/predictions_' + str(m) + '_*.h5')]
            [remove(x) for x in glob(dest_folder + '/predictions_' + str(m) + '.h5')]



