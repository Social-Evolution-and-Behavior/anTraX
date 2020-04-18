
### Requirements

anTraX works natively on machines running Linux or OSX operating system. It will benefit significantly from a multicore system. It is recommended to have at least 2GB of RAM per used core, and a similar sized swap. Computational GPU will speedup the classification phase considerably. 

** Python:**

anTraX requires Python version 3.6 or above. It is highly recommended to install and use anTraX inside a virtual environment, using conda or any other environment manager. 

** MATLAB:** 

anTraX comes with binraries compiled with MATLAB 2019a. If you have MATLAB 2019a or above installed on your machine, you do not need to install the Runtime. In case you don't, please follow the instructions to install the freely available [MATLAB Runtime](https://www.mathworks.com/products/compiler/matlab-runtime.html) for version 2019a.

** FFmpeg:**

anTraX uses [FFmpeg](https://www.ffmpeg.org/) to read video files.

To install on Ubuntu, open a terminal and type:

```console
sudo apt install ffmpeg
```

To install on OSX using [homebrew](https://brew.sh/), open a terminal and type:

```console
brew install ffmpeg
```
### Get anTraX

Change into your favorite place to install code packages, then clone the anTraX repository:

```console
git clone http://github.com/Social-Evolution-and-Behavior/anTraX.git
```

To install a specific version, use the git checkout command:

```console
cd anTraX
git checkout <version>
```

### Install anTraX

**Install the python package: **

To install the python package, run in the anTraX folder:

```console
pip install .
```
** Set envoronment variables: **

If you are using a full MATLAB installation, add these lines to your bash profile file (usually `~/.bash_profile` on OSX,   `.profile` on Linux):

```bash
export ANTRAX_PATH=<full path to anTraX repository>
export ANTRAX_USE_MCR=False
```

Otherwise, if you are using MCR, add these lines:

```bash
export ANTRAX_MCR=<full path to MCR installation>
export ANTRAX_PATH=<full path to anTraX repository>
export ANTRAX_USE_MCR=True
```

For the changes to take effect, run:
```console
source ~/.bash_profile
```

** Setup MATLAB (full MATLAB mode):**

**Note**: You do not need to do these steps if you are using the compiled binaries!

In case you have MATLAB installed (i.e. you are not using the compiled binaries), you will need to install the [MATLAB engine for python](https://www.mathworks.com/help/matlab/matlab_external/install-the-matlab-engine-for-python.html). Take care to install this in the same python environment you installed anTraX to.

You will also need to compile a mex file. In the matlab console, type:

```console
cd <path-to-anTraX>/matlab
mex popenr.c
```
If you intend to use anTraX within an interactive MATLAB session (requires an active license), add the repository to your search path. In the MATLAB console, type:

```console
addpath(genpath(<path-to-anTraX>/matlab));
```
Save the path if you want it to hold for future sessions.

**Developer mode:**

If you use a full MATLAB installation, changes to the MATLAB source code of anTraX will take effect immediately, as it is always run from the repository directory. If you use MCR, you will need to compile your changes for them to take effect.

Changes made to the python source code will take effect only after reinstalling the package. Alternatively, for changes to take effect immediately when you make them, you can install the package in editable mode:

```console
cd anTraX
pip install -e .
```

**Installation on computer clusters:**

Please refer to the [HPC section](hpc.md#installation).
