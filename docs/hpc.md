### Installation

In principle, anTraX installation on an HPC environment is the same as installation on any other Linux machine. The main difference is that typically, you will not have administrator privileges to intall system-wide packages on the HPC. Luckily, there are not many of those required by anTraX. You will also need to install MATLAB Runtime for version 2019a. You **do not** need to install MATLAB engine for python.

We recommend using a conda environemnt to setup anTraX on HPC, as it enables installation of required system packages such as [ffmpeg](https://anaconda.org/conda-forge/ffmpeg). If some packages are still missing and are not available in conda, work with your system administrator to find a solution.

If you plan on using DeepLabCut, install it into the python environment, and set it to 'light mode'  in  the bash profile file:

```bash
export DLClight=True 
```

### anTraX workflow on HPC

As computer clusters do not typically support interactive work, this will need to be done on a PC. An example for a tracking workflow using a computer cluster will be as follows:

1. Prepare the experimental directory/ies on a PC.
2. Configure a tracking session for each experimental directory on the PC. 
3. Sync the experimental directories into the HPC environment.
4. Run batch tracking on the HPC (see below).
5. If you have a trained blob classifier, jump to step 7. Otherwise, sync tracking results back to the PC, and create a training set using the interactive interface. 
6. Sync again to the HPC, and train the classifier. 
7. Run  the `classify` and `solve` commands in batch mode on the HPC.
8. Sync the results back to your PC.

It is recommended to use an incremental tool such as `rsync` to speed up data transfer. 

### Batch run on HPC environment 

If you are on an HPC environment, using the SLURM workload manager, you can run each of the batch commands (`track`, `classify`, `solve` and `dlc`) using the `--hpc` flag:

```console
antrax <command> <experiments> --hpc [--dry] [--hpc-options <opts>]
```

anTraX will then submit a SLURM job for each experiment, each containing a task for each video in the experiment. 

The optional `--dry` flag will create a SLURM jobfile, but will not submit it. It is useful to make changes to the sbatch options not currently supported by the anTraX interface.

The optional `--hpc-options` argument can control some of the SLURM options and accepts a comma separated list of some of the following options:

`throttle=<throttle>`

Number of tasks to run in parallel for each job.

`partition=<partition>`

The partition to run in (otherwise, use the system default).

`email=<email>`

Send an email for start/end of each job.

`cpus=<n>`

Allocate a specific number of cpus per task. The default value will vary according to the command (2 for tracking, 4 for classification/propagation/dlc, 12 for training).

`time=<time>`

Allocate time for task. Argument is a time string in the format supported by the `sbatch --time <time>` command (see [here](https://slurm.schedmd.com/sbatch.html)).

`mem-per-cpu=<mem>`

Allocate memory per task CPU. Argument in the format supported by the `sbatch --mem-per-cpu <mem>` command (see [here](https://slurm.schedmd.com/sbatch.html)).


**Note:** the commands `export-jaaba` and `run-jaaba`  do not currently support hpc mode.