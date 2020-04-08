
### Requirements

anTraX works natively on machines running Linux or OSX operating system. It will benefit significantly from a multicore system. It is recommended to have at least 2GB of RAM per used core, and a similar sized swap. Computational GPU will speedup the classification phase considerably. 

### Python

anTraX requires Python version 3.6 or above. It is highly recommended to install and use anTraX inside a virtual environment, using conda or any other environment manager. 

### MATLAB

anTraX required MATLAB 2019a or above. If you have a licensed MATLAB installed on your machine, you are good to go. Otherwise, binaries compiled with MATLAB 2019a are also supplied. To run the binaries, install the freely available [MATLAB Runtime](https://www.mathworks.com/products/compiler/matlab-runtime.html) for version 2019a.

### Other system dependencies 

On Ubuntu:

```console
sudo apt install ffmpeg git tk-dev
```

On OSX using [homebrew](https://brew.sh/):

```console
brew install ffmpeg
```
### Clone the repository

Change into your favorite place to install code packages, then clone the anTraX repository:

```console
git clone http://github.com/Social-Evolution-and-Behavior/anTraX.git
```

To install a specific version, use the git checkout command:

```console
cd anTraX
git checkout <version>
```

### Install

To install the python package, run in the anTraX folder:

```console
pip install .
```

If you are using a full MATLAB installation, add these lines to your `~/.bash_profile` (on OSX) or  `.profile` (Linux):

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

### Add anTraX to your MATLAB path

anTraX can be used without oppening an interactive matlab session, by using the command line interface. This is the recommended way of running anTraX. However, it can also be run interactively within a MATLAB session, which is useful if you want to make code changes, or if you are a MATLAB user who would like to analyze tracking results with MATLAB.

If you intend to use anTraX within an interactive MATLAB session (requires an active license), add the repository to your search path. In the MATLAB command line:

```matlab
addpath(genpath(<path-to-anTraX>/matlab));
```

To do this automatically each time you launch MATLAB, add these lines to your `start.m` file.

### Developer mode

If you use a full MATLAB installation, changes to the MATLAB source code of anTraX will take effect immediately, as it is always run from the repository directory. If you use MCR, you will need to compile your changes for them to take effect.

Changes made to the python source code will take effect only after reinstalling the package. Alternatively, for changes to take effect immediately when you make them, you can install the package in editable mode:

```console
cd anTraX
pip install -e .
```

### Installation on computer clusters

Please refer to the [HPC section](hpc.md#installation).
