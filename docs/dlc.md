### DeepLabCut

[DeepLabCut](http://www.mousemotorlab.org/deeplabcut) is a popular software that uses deep neural networks  for pose-tracking animals in videos, developed by the [Mathis lab](http://www.mousemotorlab.org/) at Harvard University. 
anTraX includes an interface to export cropped single-animal examples from tracked experiments to be labeled in the DeepLabCut interface, as well as options to run trained DLC models in the anTraX interface without the need to export cropped videos from entire experiment. This integration allows to create efficient pipelines that pose-track marked individual animals in large groups.

### The anTraX/DLC workflow

* Track an experiment using anTraX.
* Export a subset of single-animal images from anTraX to DeepLabCut.
* Train a DLC model
* Use the trained DLC model to track all single ant tracklets in the anTraX session. This is done using a custom anTraX function that feeds cropped single ant videos to DLC.
* The estimated bodypart positions from DLC is saved and loaded together with the centroid position of the ants.  

### Install DeepLabCut

Install the DeepLabCut package into your python environment:

```console
pip install deeplabcut
```

### Export single ant videos for training 

To export training images from anTraX to DLC project, run:

```console
antrax export-dlc-trainset <expdir> <dlcdir> [OPTIONS]
```

This will export example single ant frames from the experiment in `expdir` to the DeepLabCut project directory `dlcdir`.  If `dlcdir` doesnt exist, a new DLC project will be created (a date string will be appended to that directory name per the DeepLabCut convention).

`--nimages <nimages>`

By default, 100 randomly selected images will be exported. Change this using this option.

`--movlist <movlist>`

By default, anTraX will select frames from all movies in the experiment. This can be changed by using this option. Example for valid inputs incluse: `4`, `3,5,6`, `1-5,7`.

`--antlist <antlist>`

By default, anTraX will select frames from all ants in the experiment. This can be changed by using this option, providing a comma separated list of IDs. Example: `--antlist BB,GP,PO`.

`--video`

By default, the extracted frames will be saved as images in the DeepLabCut project directory. You can select to save them as videos using this flag.

`--session <session>`

If your experiment includes more than one configured session, anTraX will export examples  from the last configured one. Use this option to choose a session explicitly.

### Train a DeepLabCut model

At this point, you are ready to train your DeepLabCut model. Refer to the package [webpage](http://www.mousemotorlab.org/deeplabcut) for a tutorial.

### Run

Once the model is trained and ready, you can use the anTraX interface to easily run it on the tracked experiment:

```console
antrax dlc <experiments> --cfg <path-to-dlc-cfg-file> [OPTIONS]
```

The `experiments` argument can be either a full path to an experimental directory, a full path to a text file with a list of experimental directories (all of which will run in parallel), or a full path to a folder that contains one or more experimental directories (all of which will run in parallel).

The required argument `cfg` is the full path to the project file of the trained DeepLabCut model.

The classify command accepts the following options:

`--movlist <list of movie indices>`

By default, anTraX will process all movies in the experiment. This can be changed by using this option. Example for valid inputs incluse: `4`, `3,5,6`, `1-5,7`.

`--session <session name>`

If your experiment contains more than one configured session, anTraX will run on the last configured one. Use this option to choose a session explicitly.

### Loading and analyzing postural data

The DeepLabCut pose tracking results can be loaded using the anTraX python interface:

```python
from antrax import *

ex = axExperiment(<expdir>, session=None)
antdata = axAntData(ex, movlist=None, antlist=None, colony=None)
antdata.set_dlc()
```

Note that loading pose tracking data for a full experiment might take some time if the experiment is long. Consider loading a partial dataset using the `movlist` argument for initial exploration before doing a full analysis.

Refer to the example jupyter notebook for an elaborated example.






