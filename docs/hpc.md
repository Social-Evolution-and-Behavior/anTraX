### Installation

In principle, anTraX installation on an HPC environment is the same as installation on any other Linux machine. The main difference is that typically, you will not have administrator priviliges to intall system-wide packages on the HPC. Luckily, there are not many of those required by anTraX. Also install MATLAB Runtime for version 2019a. You **do not** need to install MATLAB engine for python.

We recommend using a conda environemnt to setup anTraX on HPC, as it enables installation of several packages such as [ffmpeg](https://anaconda.org/conda-forge/ffmpeg). If some pckages are still missing and are not available in conda, work with your system administrator to find a solution.

If you plan on using DeepLabCut, install it into the python environment, and set it to 'light mode'  in  `~/.profile`:

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
antrax <command> <experiments> --hpc --hpc-options <opts>
```

anTraX will then submit a SLURM job for each experiment, each containing a task for each video in the experiment. 

The optional `hpc-options` argument can controlled some of the SLURM options and accepts a comma seperated list of some of the following options:

`throttle=<throttle>`

Number of tasks to run in parallel for each job.

`partition=<partition>`

The partition to run in (otherwise, use the system default)

`email=<email>`

Send an email for start/end of each job.

`cpus=<n>`

Allocate a specific number of cpus per task. The default value vary according to the command (2 for tracking, 4 for classification/propagation/dlc, 12 for training).



**Note:** the commands `export-jaaba` and `run-jaaba`  do not currently support hpc mode.