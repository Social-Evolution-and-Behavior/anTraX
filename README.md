![trails](https://github.com/Social-Evolution-and-Behavior/CATT/blob/master/docs/images/trails.png)

# **CATT** -  **C**olored **A**nts **T**racking **T**oolbox

CATT is a software for video tracking ants tagged with a unique pattern of color dots. It was designed for behavioral experiment using the Clonal Raider Ant [*Ooceraea biroi*](https://en.m.wikipedia.org/wiki/Ooceraea_biroi), but can be used for any other model system. CATT is a **brute force** type tracking algorithm, which was designed to handle high throuput long duration experiments (many colonies over many days). Therefore, it will require considerable computational resources. 

The software was designed and written by Jonathan Saragosti and Asaf Gal of the [Laboratory of Social Evolution and Behavior](https://www.rockefeller.edu/research/2280-kronauer-laboratory/) in the Rockefeller University, and is distributed under the [GPLv3](https://github.com/Social-Evolution-and-Behavior/CATT/blob/master/LICENSE) licence.


## Requirements

CATT works natively on machines running Linux or OSX operating system. It benefits significantly from a multicore system. It is recommended to have at least 2GB of RAM per used core, and a similar sized swap. Computational GPU will speedup the classification phase considerabley. 

### MATLAB

CATT was programmed and tested using MATLAB version 2018b. Other versions might have compatibility issues.

Required toolboxes: 
* Image processing
* Statistics and machine learning
* Computer vision
* Parallel computing

### Python

The image classification part of the tracking algorithm is implemented in [keras](http://keras.io), with tensorflow backend. For it to work, a python3 virtual environment needs to be setup. Detailed installation instructions are given in the [wiki page](https://github.com/Social-Evolution-and-Behavior/CATT/wiki)

## Installation

See wiki's [Installation and setup page](https://github.com/Social-Evolution-and-Behavior/CATT/wiki/Installation-and-setup).

## Usage

Detailed usage instructions are given in the [wiki pages](https://github.com/Social-Evolution-and-Behavior/CATT/wiki) of this github repository.

## Limitations

* CATT uses optical flow for linking between ant blobs in consecutive frames. As such, it requires some overlap between blobes for linking. This means that the minimal framerate required depends on the maximal speed of the ants. For *O. biroi*, 10 fps is usually enough, but for faster ants even standrd video speeds (25-30 fps) might be a problem. CATT does not currently supports other linking methods such as the Hungarian Linear Assigment algorithm. 

* CATT does not currently try to break a multi-ant segmented blob into individual ant blobs, the way other tracking software do. This is because *O. biroi* ants interactions are often very close range, which makes this process error prone. This design decision make the tracking sometimes seem suboptimal in cases where the interactions are brief. In the future, we plan to add a module that will identify these cases, and will use the resolved composition (i.e. which ants are in that blob) to identify exact locations withing multi ant blobs.

* As we designed CATT for very long duration experiments, that entail manual verification and fixing of the tracks impratical, we chose a conservative approach, and prefer to have a "no location" for an ant rather than a wrong location. If your experiments are short (one or two videos), you might do better with other tracking solutions.

## References

TBA
