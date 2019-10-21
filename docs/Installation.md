
### Install dependencies 

On Ubuntu:

```
sudo apt install ffmpeg git tk-dev
```

On OSX using [homebrew](https://brew.sh/):

```
brew install ffmpeg
```

### Download CATT

Change into your favorite place to install code packages (lets call it `$CODEROOT` from now on), then clone the repo:

```
cd $CODEROOT
git clone http://github.com/Social-Evolution-and-Behavior/CATT.git
```

### Install python 3.6

CATT uses tensorflow, which unfortunately doesn't support the latest python 3.7. Therefore, you need to make sure you have python 3.6 installed (not necessarily as your default python).

First, check your installed python version:

```
python3 -V
```

If it’s 3.6.*, you’re good to go!

Otherwise, to install on Ubuntu:

```
sudo apt install python3.6
```

If you get a "no such package" error, try adding the "dead snakes" repository: 

```
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install python3.6
```

To install on OSX using homebrew:

```
brew unlink python # If you have installed (with brew) another version of python
brew install https://raw.githubusercontent.com/Homebrew/homebrew-core/f2a764ef944b1080be64bd88dca9a1d80130c558/Formula/python.rb
```

If you have several python versions and your environment is getting out of control, I recommend checking out [pyenv](https://hackernoon.com/reaching-python-development-nirvana-bb5692adf30c) to manage per-project python versions.

### Install pipenv

CATT uses `pipenv` to create a virtual python environment and install all python dependencies. You will first have to install `pipenv`:

```
pip3 install --user pipenv
```

Note that you might need to add the directory in which pipenv scripts were installed to the search path - look for a warning massage in the install std output. If so, add it to path in `~/.bash_profile`(OSX) or `~/.profile` (Linux). Don’t forget to source.

### Setup python environment 

Go into the CATT directory, and install the dependencies (might take a few minutes):

```
cd $CODEROOT/CATT/
pipenv install 
```

If python3.6 is not your default python, you might need to explicitly give `pipenv` A link to the python executable:

```
pipenv install —-python <path-to-python3.6>
```

A virtual environment named `CATT` will be created with all the required python dependencies. The program will run its python scripts inside this virtual environment to avoid messing with other python environments you might have. If you want to access this environment, go into the CATT directory and run:

```
cd $CODEROOT/CATT
pipenv shell 
```

To go out simply run `exit`. 

### Add CATT to your MATLAB path

In the MATLAB command line:

```
addpath(genpath('$CODEROOT/CATT'));
rmpath('$CODEROOT/CATT/OBS/');
```

To do this automatically each time you launch MATLAB, add these lines to your `startup.m` file.

### Compile the popenr mex file

In the MATLAB command line:

```
cd $CODEROOT/CATT/matlab/external/popenmatlab/'
mex popenr.c
```


## Troubleshooting

### pyenv/tkinter issue

The project requires tkinter package to be installed (through the deeplabcut dependency. This package is installed system-wide, and needs to be there when you configure the pyenv python environment. If you get the error "ModuleNotFoundError: No module named '_tkinter'", reinstall the pyenv python environment:

```
cd /path/to/your/antrax/repo
pyenv uninstall 3.6.8
sudo apt install tk-dev
pyenv install 3.6.8
```

### wxPython issue

wxPython is required by DeepLabCut, and is installed by a direct link to wheel. If you get the error "ModuleNotFoundError: No module named 'wx'", try installing it with:

```
pipenv install --skip-lock https://extras.wxpython.org/wxPython4/extras/linux/gtk3/ubuntu-18.04/wxPython-4.0.3-cp36-cp36m-linux_x86_64.whl
```

For Ubuntu 16.04, replace the appropriate point in the link.

### DeepLabCut on server/hpc environment

When running DeepLabCut on sever environment, you will need to disable the graphical components by setting:

```
export DLClight=True
```

See [https://github.com/AlexEMG/DeepLabCut/issues/185](https://github.com/AlexEMG/DeepLabCut/issues/185)

### pymatreader install from git issue

anTraX uses a modified version of the pymatreader package to read matfiles into python. If you get errors installing it directly from git, clone and install it manually:

```
git clone git@github.com:Social-Evolution-and-Behavior/pymatreader.git /target/directory
cd /path/to/your/antrax/repo
pipenv install /target/directory/pymatreader
```



