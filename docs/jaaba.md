
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




### anTraX-specific perframe features




### Training a classifier


### Applying the classifier to an experiment 


 
