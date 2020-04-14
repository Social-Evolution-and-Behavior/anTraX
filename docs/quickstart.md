In this tutorial, we will track a small example dataset, included with anTraX. The dataset consists of half an hour recording of a colony of 16  *Ooceraea biroi* ants, split into 6 video files,each of  5 minutes duration. This dataset is a short segment of the longer [J16 benchmark dataset](datasets.md#dataset-j16), which is also available for dowload together with all the other benchmark datasets. 

All commands are to be entered in the bash terminal of your system, in the same environment anTraX was installed into.

### Dowload the test dataset

```console
git clone http://github.com/Social-Evolution-and-Behavior/anTraX-data.git
```

Inside the repository there is a directory called 'JS16' (the experimental directory). For a full  explanation of the structure of the experimental directory, refer to the [Preparing data for anTraX](data_organization.md) section of the documentations.

### Open the antrax app

The dataset includes a pre-configured anTraX session. To explore and change the parameters, open the anTraX configuration app:

```console
antrax configure <path-to-JS16>
```

For full  explanation of the configuration process and the tracking parameters, refer to the [Configuring a tracking session](configuration.md) section of the documentations. 

### Track

The first step is the tracking. To run it, enter in the terminal:

```console
antrax track <path-to-JS16> --nw 3
```

The `--nw 3` option tells anTraX to run 3 parallel tracking threads. For full  listing of the options for the track command, refer to the [Runnning the tracking](tracking.md) section of the documentations.  

### Train a classifier

Once tracking is complete, the next step is to train a blob classifier. The dataset includes an already trained classifier and a set of examples. But for the purpose of this example, lets run an aditional round of training with 3  epochs:

```console
antrax train <path-to-JS16>/antrax_demo/classifier --ne 3
```

For a full explenation of the training step, including how to generate a training dataset, see the [Classifying tracklets](classification.md) section of the documentations.  

### Classify tracklets

Once the classifier is trained, we can classify all the tracklets in the experiment:

```console
antrax classify <path-to-JS16>
```
For full  listing of the options for the classify command, refer to the [Classifying tracklets](classification.md#classifying-tracklets)  section of the documentations.  

### Run graph propagation 

The final step of the algorithm is running the graph propagation, or the 'solve' step:

```console
antrax solve <path-to-JS16>
```

For full  explanation of this step and the all the command options, refer to the [Graph propagation](propagation.md) section of the documentations. 

#### Validate tracking

Now that tracking is complete, we can verify its accuracy and estimate the tracking error:

```console
antrax validate <path-to-JS16>
```
See the [Validating tracking results](validation.md) section and the anTraX publication for explenation about the validation process.

### Open graph-explorer

To debug the tracking, manually fix an important point in the experiment, or just view the tracklet graph, use the graph-eexplorer app:

```console
antrax graph-explorer <path-to-JS16> 
```

See [Using the graph explorer to view and debug ID assignments](propagation.md#using-the-graph-explorer-to-view-and-debug-id-assignments) for details about using the app.

### Loading and analyzing tracks

To load and analyze the tracking results, see the  [Working with tracking results - python](analysis_nb.ipynb) and  [Working with tracking results - matlab](analysis_matlab.ipynb) pages.

