
### The anTraX/JAABA workflow

* Track an experiment using anTraX.
* Write tracks and perfume data in JAABA-readable format.
* Train a classifier using the JAABA interface
* Classify the entire dataset using either the JAABA interface or anTraX interface.
* The JAABA-generated scores for each behavioral classifier will be imported together with the spatial coordinates of each animal.

### Install JAABA

Install the JAABA package from GitHub:

```console
git clone https://github.com/kristinbranson/JAABA.git
```

Copy antrax configuration files into the JAABA directory:

```console
cp $ANTRAX_PATH/matlab/jaaba/*.xml $ANTRAX_JAABA_PATH/perframe/params/
```

### Write tracks and perframe data for JAABA



```console
antrax export-jaaba <expdir>  

```

The export-jaaba command accepts the following options:


`--nw <number of workers>`

anTraX will parallelize the traking by video. By default, it will use two MATLAB workers. Depending on your machine power, this can be changed by using this option.

`--movlist <movlist>`

By default, all movies will be processed, which might take some time. Change this using this option.

`--session <session name>`

If your experiment contains more than one configured session, anTraX will run on the last configured one. Use this option to choose a session explicitly.


### The JAABA directory structure

anTraX will create a directory called `jaaba` under the session directory. In that directory, a subdirectory for each movie in the experiment will be created (JAABA consider each movie a separate experiment, and will therefore call each of these subdirectories an experimental directory). In each of these directories, there will be a soft link to the movie, named `movie.mp4` (or `movie.avi` etc. if your video files extension is different), and a mat file called `trx.mat` containing the trajectories in JAABA-compatible format. A subdirectory called `perframe` will also be generated, and will hold the perframe data.

![expdir structure](/images/jaaba_directory_structure.png "jaaba directory structure")


### anTraX-specific perframe features




### Training a classifier

Once the export step is finished, you are ready to use the JAABA interface to load the data and train the classifier. Refer to the [JAABA documentation page](http://jaaba.sourceforge.net/index.html) for information on this step.

### Applying the classifier to an experiment 


To run a trained JAABA classifier (defined a `.jab` file), run the command:

```console
antrax run-jaaba <expdir>  --jab <jabfile>
```

The run-jaaba command accepts the following options:

`--nw <number of workers>`

anTraX will parallelize the traking by video. By default, it will use two MATLAB workers. Depending on your machine power, this can be changed by using this option.

`--movlist <movlist>`

By default, all movies will be processed, which might take some time. Change this using this option.

`--session <session name>`

If your experiment contains more than one configured session, anTraX will run on the last configured one. Use this option to choose a session explicitly.

*** Note: *** The `run-jaaba` ccommand does not currently support the `--hpc` option to run on a computer cluster.

### Loading and analyzing JAABA scores

For each ant in each frame, JAABA will assign a classification score. A positive score will imply a positive classification, and a negative score will imply a negative classification. The larger the absolute value of the score, the stroger is the confidence in the classification. 

To load the results using the anTraX python interface:

```python
from antrax import *

ex = axExperiment(<expdir>, session=None)
antdata = axAntData(ex, movlist=None, antlist=None, colony=None)
antdata.set_jaaba()
```

Consider loading a partial dataset using the `movlist` argument for initial exploration before doing a full analysis.

Refer to the example jupyter notebook for a more elaborated example.
