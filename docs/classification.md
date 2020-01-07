### Classification workflow

In this step we will classify each tracklet that was marked as possible single ant tracklet. Each of these tracklet will be assigned as either:

* An ant ID from the list of possible IDs
* A non-ant tracklet, wither as a general category or a specific one if such exist in the classifier.
* A multi ant tracklet
* An ambigious tracklet ('Unknown') in case the classifier couldn't make a decision.  

Each tracklet is classified by first classifying all blob images belonging to that tracklet, using the *blob classifier* and then weighting these classifications to produce a whole tracklet classification. The blob classifier is a trained deep convolutional network (CNN), that needs to be trained on a trainset of pre-classified blob images

### Creating a training set

The blob classifier is a trained deep convolutional network (CNN), that needs to be trained on a trainset of pre-classified blob images. anTraX includes an interactive GUI application to prepare such a training set from a tracked experiment:

```console
antrax extract-trainset <expdir> [--session <session>]
```

The app will display blobs images from a randomly selected tracklet, as well as info about the tracklet in the textbox below. Using the buttons on the right, you can select the label appropriate for the tracklet, and either export all images to the train set (using the 'export all' button), or select a subset using the 'select frames' button (a frame selection window will open). You can move between tracklets using the 'Next' and 'Back' buttons.
See the [tips and best practices](tips.md#training-and-classification) page regarding what are good training set examples.

By default, the app will load tracklet from the first tracked movie. Tracklets from other movies can be loaded using the 'Tracklet' menu.

![trainset extraction](images/extract-trainset1.png)

![frame selection](images/extract-trainset-frame-selector.png)


### Merging training sets

The exported examples are saved as images in the experimental directory, under `/session/classifier/examples/id/`. When creating a classifier specific to that experiment, training can be done from that directory. However, in order to create a general classifier to be used on many experiments, it is necessary to create a trainset that contain examples from a few experiments. This can be done with the command:

```console
antrax merge-trainset <source-classdir> <dest-classdir>
```

This will merge all the examples from the source classifier directory (usually `expdir/session/classifier`) into the destination classifier directory. It is recommended to keep multi-experiment classifiers seperate from any specific experimental directory to avoid confusion.

**Important:** the user is responsible for making sure the lists of  labels match when merging trainsets. Otherwise, problems might occur.

### Training the classifier

To train the classifier, run: 

```console
antrax train <classdir> [OPTIONS]
```

The `classdir` argument is a full path to the directory containing the `examples` directory, and where the classifier will be saved.

The train command accepts the following options:

`--scratch`

By default, anTraX will load a pretrained classifier if exists in the `classdir` directory, and run incremental trainnig. If the `--scratch` flag is used, it will initialize a new classifier instead. 

`--ne <ne>`

Number of training epochs to run. Default is 5.

`--target-size <size>`

The side length (in pixels) of the input image to the classifier (anTraX always use square images for classification). This option will only take effect if a new classifier is trained. By default, the size will be that of the first image read from the trainset. All other images will be resized to the target-size. 

`--name <name>`

Use a custom name for the classifier.


### Classifying tracklets

To run classification in batch mode:

```console
antrax classify <experiments> [OPTIONS]
```

The `experiments` argument can be either a full path to an experimental directory, a full path to a text file with a list of experimental directories (all of which will run in parallel), or a full path to a folder that contains one or more experimental directories (all of which will run in parallel).

The classify command accepts the following options:

`--classifier <path-to-classifier file>`

Explicit path to a classifier (`.h5` file created by the train process). By default, anTraX will use the classifier file that exist in the default location in the experimental directory `expdir/session/classifier/classifier.h5`. If it doesn't exist, an erorr will be raised.
 
`--movlist <list of movie indices>`

By default, anTraX will track all movies in the experiment. This can be changed by using this option. Example for valid inputs incluse: `4`, `3,5,6`, `1-5,7`.

`--session <session name>`

If your experiment contains more than one configured session, anTraX will run on the last configured one. Use this option to choose a session explicitly.


### Validating classification and retraining 

Once tracklet in the experiment are classifed, the extract-trainset app can be used to validate the results and export new examples if needed. For a classified experiment, the app will display also the assigned label. If it is incorrect, or if it is unclassified (labeled 'Unknown' although it is identifiable), you can add its images to the trainset the same way as before. Don't forget to choose the correct label before exporting!

The 'Filter by autoID' option in the 'Tracklet' menu can be used to show only tracklets assigned with a specific label. 

Optionally, you can formally evaluate the performance of the classifier by marking each classification as 'Correct', 'Wrong' or 'Should not have an ID' (if the tracklet is not identifiable). Doing that for a set of tracklet will give an estimate of the classifier performance per-tracklet and per-frame.

Once the trainset has been expanded, train the classifier and rerun classification in the same way as before.

![trainset extraction](images/extract-trainset2.png)
