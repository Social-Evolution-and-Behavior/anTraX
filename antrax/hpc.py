
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


def clear_tracking_data(ex, step, movlist, opts):
    # it is a good idea to clear tracking data centrally before hpc run, so we'll know which tasks failed without
    # looking at the logs

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


def antrax_hpc_job(ex, step, opts):

    # if "missing" is set, get list of videos with missing output
    if opts.get('missing', False):
        movlist = ex.get_missing(ftype=step)
    else:
        movlist = ex.movlist

    # if user movlist is given, intersect with all/missing list
    if opts.get('movlist', None) is not None:
        movlist = [m for m in movlist if m in opts['movlist']]

    # unless step is "track", run only on movies with image data
    if not step == 'track':
        movlist = [m for m in movlist if m in ex.get_file_list('images')]

    opts['taskarray'] = movlist

    # solve need special handling
    if step == 'solve':
        taskarray = None

    # clear tracking data for movlist
    if not opts.get('dry', False):
        clear_tracking_data(ex, step, movlist, opts)

    precmd = []

    if step == 'track':
        opts['jobname'] = 'trk:' + ex.expname
        opts['filename'] = 'trk'
        opts['cpus'] = opts.get('cpus', 2)
        opts['cmd'] = 'run_antrax.py track ' + ex.expdir + \
            ' --session ' + ex.session + \
            ' --movlist $SLURM_ARRAY_TASK_ID' + \
            ' --mcr'

    elif step == 'post':
        opts['jobname'] = 'pst:' + ex.expname
        opts['filename'] = 'pst'
        opts['cpus'] = opts.get('cpus', 2)
        opts['cmd'] = ''

    elif step == 'classify':

        opts['jobname'] = 'cls:' + ex.expname
        opts['filename'] = 'cls'
        opts['cpus'] = opts.get('cpus', 6)
        opts['cmd'] = 'run_antrax.py classify expdir' + \
            ' --session ' + opts['session'] + \
            ' --classdir ' + opts['classdir'] + \
            ' --movlist $SLURM_ARRAY_TASK_ID'

    elif step == 'solve':
        opts['jobname'] = 'slv:' + ex.expname
        opts['filename'] = 'slv'
        opts['cpus'] = opts.get('cpus', 4)
        opts['cmd'] = ''

    elif step == 'dlc':

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

    opts['workdir'] = ex.logsdir

    if not opts.get('dry', False):
        jobfile = create_slurm_job_file(opts)
        jid = submit_slurm_job_file(jobfile)
        print('')
        print('Job number ' + str(jid) + ' was submitted')
        print('')
    else:
        print('')
        print('Dry run, no job submitted')
        print('')
