
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

    mem_per_cpu = opts.get('mem-per-cpu', None)

    email = opts.get('email', None)

    if email is None and 'rockefeller' in HOSTNAME:
        email = USER + '@mail.rockefeller.edu'

    mailtype = opts.get('mailtype', 'ALL')
    partition = opts.get('partition', None)
    time = opts.get('time', None)
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
        if time is not None:
            f.writelines("#SBATCH --time=%s\n" % time)

        if mem_per_cpu is not None:
            f.writelines("#SBATCH --mem-per-cpu=%s\n" % mem_per_cpu)

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


def submit_slurm_job_file(jobfile, waitfor=None):

    if waitfor is None:
        waitforstr = ''
    else:
        waitforstr = '--dependency=afterok:' + str(waitfor)

    p = Popen("sbatch %s %s" % (waitforstr, jobfile), stdout=PIPE, shell=True)

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


def antrax_hpc_train_job(classdir, opts, aug_options=''):

    opts['jobname'] = 'train'
    opts['filename'] = 'hpc_train'
    opts['taskarray'] = [0]
    opts['workdir'] = opts.get('workdir', classdir)
    opts['cpus'] = opts.get('cpus', 24)
    opts['cmd'] = 'antrax train ' + classdir + \
                  ' --name ' + opts['name'] + \
                  ' --ne ' + str(opts['ne'])

    if len(aug_options) > 0:
        opts['cmd'] = opts['cmd'] + ' --aug-options ' + aug_options

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


def antrax_hpc_job(ex, step, opts, solve_step=None):

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
        movlist = [m for m in movlist if m in ex.get_file_list('images') or ex.is_parted(m)]

    # clear tracking data for movlist
    if not opts.get('dry', False):
        clear_tracking_data(ex, step, movlist, opts)

    precmd = []

    report('D', 'hpc job creation for step ' + step)

    if step == 'track':

        opts['jobname'] = 'trk:' + ex.expname
        opts['filename'] = 'hpc_track'
        opts['taskarray'] = movlist
        opts['cpus'] = opts.get('cpus', 2)
        opts['cmd'] = 'antrax track ' + ex.expdir + \
            ' --session ' + ex.session + \
            ' --movlist $SLURM_ARRAY_TASK_ID' + \
            ' --nw 1' + \
            ' --mcr'

    elif step == 'pair-search':

        opts['jobname'] = 'prs:' + ex.expname
        opts['filename'] = 'hpc_pair_search'
        opts['taskarray'] = movlist
        opts['cpus'] = opts.get('cpus', 2)
        opts['cmd'] = 'antrax pair-search ' + ex.expdir + \
                  ' --session ' + ex.session + \
                  ' --movlist $SLURM_ARRAY_TASK_ID' + \
                  ' --nw ' + str(opts['nw']) + \
                  ' --mcr'

    elif step == 'post':

        opts['jobname'] = 'pst:' + ex.expname
        opts['filename'] = 'hpc_pst'
        opts['taskarray'] = movlist
        opts['cpus'] = opts.get('cpus', 2)
        opts['cmd'] = ''

    elif step == 'classify':

        opts['jobname'] = 'cls:' + ex.expname
        opts['filename'] = 'hpc_classify'
        opts['taskarray'] = movlist
        opts['cpus'] = opts.get('cpus', 6)
        opts['cmd'] = 'antrax classify ' + ex.expdir + \
            ' --classifier ' + opts['classifier'] + \
            ' --session ' + ex.session + \
            ' --movlist $SLURM_ARRAY_TASK_ID'

    elif step == 'solve':

        opts['jobname'] = 'slv' + str(solve_step) + ':' + ex.expname
        opts['filename'] = 'hpc_solve' + str(solve_step)
        if solve_step == 2:
            opts['taskarray'] = opts['glist']
        else:
            opts['taskarray'] = opts['movlist']
        opts['cpus'] = opts.get('cpus', 4)
        opts['cmd'] = 'antrax solve ' + ex.expdir + \
            ' --session ' + ex.session + \
            ' --movlist $SLURM_ARRAY_TASK_ID ' + \
            ' --nw 1 ' + \
            ' --step ' + str(solve_step) + \
            ' --mcr'

        if opts['c'] is not None:
            opts['jobname'] = 'slv:' + ex.expname + ':' + str(opts['c'])
            opts['filename'] = 'hpc_solve_col_' + str(opts['c']) + '_'
            opts['cmd'] += ' --clist ' + str(opts['c'])

    elif step == 'dlc':

        opts['jobname'] = 'dlc:' + ex.expname
        opts['filename'] = 'hpc_dlc'
        opts['taskarray'] = movlist
        opts['cpus'] = opts.get('cpus', 6)
        opts['cmd'] = 'antrax dlc ' + ex.expdir + \
            ' --session ' + ex.session + \
            ' --cfg ' + opts['cfg'] + \
            ' --movlist $SLURM_ARRAY_TASK_ID'

    else:

        report('E', 'Command unknown or not supported in hpc mode')
        return

    opts['workdir'] = ex.logsdir

    report('D', 'hpc job created')

    if ANTRAX_DEBUG_MODE:
        print(opts)

    jobfile = create_slurm_job_file(opts)
    print('')
    print('Jobfile created in ' + jobfile)
    print('')

    waitfor = opts.get('waitfor', None)

    if not opts.get('dry', False):
        jid = submit_slurm_job_file(jobfile, waitfor=waitfor)
        print('Job number ' + str(jid) + ' was submitted')
        print('')
    else:
        jid = 0
        print('Dry run, no job submitted.')
        print('')

    return jid
