![trails](https://github.com/Social-Evolution-and-Behavior/anTraX/blob/master/docs/images/trails.png)

# **anTraX**: high throughput tracking of color-tagged insects

anTraX is a software for video tracking of ants and other small animals tagged with a unique pattern of color dots. It was designed for behavioral experiment using the Clonal Raider Ant [*Ooceraea biroi*](https://en.m.wikipedia.org/wiki/Ooceraea_biroi), but can be used for any other model system. anTraX is a **brute force** type tracking algorithm, which was designed to handle high throuput long duration experiments (many colonies over many days). Therefore, it will require considerable computational resources. 

The software was designed and written by Jonathan Saragosti and Asaf Gal of the [Laboratory of Social Evolution and Behavior](https://www.rockefeller.edu/research/2280-kronauer-laboratory/) in the Rockefeller University, and is distributed under the [GPLv3](https://github.com/Social-Evolution-and-Behavior/CATT/blob/master/LICENSE) licence.


## Requirements

anTraX works natively on machines running Linux or OSX operating system. It benefits significantly from a multicore system. It is recommended to have at least 2GB of RAM per used core, and a similar sized swap. Computational GPU will speedup the classification phase considerabley. 


## Installation and usage

See online documentation at https://antrax.readthedocs.io/. An example dataset to be used in the tutorial can be found [here](https://github.com/Social-Evolution-and-Behavior/anTraX-data). All datasets used to benchmark anTraX are [available from the Zenodeo repository](https://zenodo.org/record/3740547).

## References

Read more in our [preprint](https://www.biorxiv.org/content/10.1101/2020.04.29.068478v1).
