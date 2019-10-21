### What is a session?

A tracking *session* is a run of the algorithm with a set of settings and parameters. In the typical case, you will only create one session per experiment. However, sometime it is usefull to play around with a different parameter set without overwriting existing results, or track different parts of the experiment with different parameters sets. In these cases, multiple session will be created. The session, together with its parameters ancd results, is stored as a subdirectory of the experimental directory and is named by the session identifier name.

### Launch the anTraX app

To create and configure a tracking session, simply launch the anTraX app by entering the command:
```
antrax
```
In the MATLAB command line. Note that any configuration changes are saved on-the-fly. When finished, just exit the app and the session will be saved. 


### Create/load a tracking session

First, open an experiment by selecting  `Open` in the `Experiment` taskbar menu (or choose an experiment you previously worked on the `Recent` menu). Then, in the `Session` menu, either select an existing session or select `New` to create a new one.
Once a session is loaded/created, the configuration workflow will appear as tabs in the application window.

### Display video frames
The anTraX application window is divided into two main parts: configuration panel on the left, and the frame viewer on the right. The displayed image will be augmented according to the configuration.
The frames in the experiment can be browsed by using the selectors on the top part of the configuration panel, which will appear in most of the configuration tabs. A frame in the experimement can be defined either by its video index (the first selector) and the frame index in that video (the second selector), or by its total index in the experiment (the third selector).

![Frame display selection](/images/frame_selection.png)

### Create a background image

The first step is to generate a background image.

![Create background tab](/images/background_creation.png)

Use the ***method*** dropdown to select between the possible background computation methods. The ***median*** method computes the background as the per-pixel per-channel median of a set of randomly selected frames. The ***max*** method computes the background as the per-pixel per-channel max value. Select the number of frames for generating a background image. Obviously, the more frames are used the better the background frame is, especially when median method is used. However, 20 will usually give a good tradeoff between computation time and quality. Frames are randomly selected from the frame range.

***One BG*** option will generate a single background to be used throughout the tracking. With this option, you can select a frame range for selecting frames (useful for cases where some parts of the experiment are more suitable for background calculation)

***BG per subdir*** will generate a separate background frame for each subdirectory of videos. This option is useful for cases where there are movements between the location of the arena in the frame between recording session, of some other change in filming conditions.

The ***Create BG*** button will start the background creation process. Depending on the parameters, this might take several minutes. After the computation is done, the new background will be displayed. If several backgrounds are created, you can choose which one is displayed from the BG file dropdown menu.

All background images are saved as png files in the directory `expdir/session/parameters/background/`.


### Set the spatial scale
In the second tab, the spatial scale of the videos will be defined. This is required to have all the parameters and results in real world units, which is essential for  parameters to be generalized between experiments, and tracking results comparable between experiments.

To set the scale, choose a feature in the image of which the dimensions are known. Choose the appropriate tool from the drop down menu (either ***Circle*** or ***Line***), press the ***Draw*** button, and adjust the tool to fit the feature.

When done, enter the Length/Diameter of the feature om mm  in the box, and finish by pressing the ***Done*** button.

![Scale tab](/images/scale.png)

### Create an ROI mask

The ***ROI Mask*** is used to define the regions of the image in which tracking is performed. 

To set a mask, start by either a white mask ("track everywhere") by pushing the ***Reset to White*** or a black mask ("track nowhere") by pushing the ***Reset to Black***. Then, add and remove regions by selecting a tool from the dropdown and drawing on the image. Adjust by dragging the anchor points. When don,e double click the tool. You can repeat this process untill the ROI is ready.

The ***Multi Colony*** option is used to control how a mask with several disconnected ROIs should be treated. If these regions correspond to separate ant colonies. If checked, each of these regions will be treated as a separate colony, containing a full and fixed set of identified ants, and will be saved separately. Use the dropdown to control the numbering order of the ROIs, and the Assign colony labels buttons to manually assign labels to each numbered colony (avoid white spaces in the labels).

The ***Open Boundry*** option is used to mark parts of the ROI perimeter that are "Open" to ants getting in and out of the ROI. This is used to optimize tracking in these regions. Otherwise, the ROI is assumed to be completely closed. 

All ROI and colony masks are saved as png files in the directory `expdir/session/parameters/masks/`.

### Tune the segmentation

anTrax segment a background substracted image into foreground and background, with the foreground being composed of several connected components ('blobs'). This is a multi parameter process that should be tuned for each experiment. 

On the ***Segmentation*** tab, several of the segmentation parameter can be tuned, while displaying the results. The control parameters include:

***Segmentation threshold:*** in units of gray value difference between image and background.

***Adaptive threshold:*** if checked, the threshold will be adjusted locally as a function of the background brightness, causing the segmentation to be more sensitive in darker areas.

***Min area (pixels):*** Blobs below this threshold are discarded.

***Closing (pixels):*** Optional morphological closing, that merge blobs separated by few pixels.

***Opening (pixels):*** Optional morphological opening, eroding thin pixel lines.
Min intensity (gray level). Blobs with maximum intensity lower than this value will be discarded.

***Convex hull:*** Fill in the blob convex hull. Using in cases where there is bad contrast between parts of the ant and the background.

***Fill holes:*** Useful when very bright tags are used, that do not have good contrast with the background and appear as 'holes' in the blob.

***Min intensity:*** Optional blob filter, which discard blobs with maximal intensity lower than the threshold value.

The display of the segmented frame can be configured usng the checkboxes below the frame selectors: ROI mask can be turned on/off, blobs can be shown as convex hull curves (default) or as colored segmented regions (better to check the fine details of the segmentation). Text showing the blob area in pixels and maximum intensity value can be displayed. 

![Image segmentation](/images/segmentation.png)

### Tune single ant size range

anTrax uses the size of individual ant for filtering possible single ant tracklets for classification, and also for calibrating the linking algorithm. The single ant size is defined by the possible size range, which is adjusted in the ***single ant*** tab. For tunning these range parameters, the blobs detected in the displayed frames are marked with green outlines if they are in the single ant range, with red if they are larger, and with pink if they are smaller. It is recommended to scan a decent number of frames throughout the experiment to look for neear-threshold cases. Note that the range doesnt need to perfectly classify blobs, but to capture the possible size range for single ants.

![Single ant size range](/images/single_ants.png)


### Tune the linking

TBD

### Enter individual tags information 

Before classification, you will need to provide the program a list of the ants in the experiment (identified by their color tags). In case your classifier is trained to identify other types of objects (food, brood, prey insect etc.) you will need to provide these as well.

The list of labels must match the the one the classifier is trained with (read more about classifiers).

If your experiment is a multi colony one, it is assumed the ID list is the same for all colonies in the experiment. If it is not the case, give a list that include all possible IDs, and adjust it using a config file as described below.

The label list is defined by the file `expdir/session/parameters/labels.csv`. Each row in the file contains two entries. The first is the label ID, and the second is the category. Three categories exist: ant_labels, noant_labels, and other_labels. The list must include the label 'Unknown' in the other_labels category. 

The ***IDs*** tab is an easy way to configure the list of labels for ant marked with two color tags: First, check the boxes of the color tags used. A label list containing all possible combinations will be created. Next, trim the list to include only the actually used combinations. Also add no-ant labels as needed. 

### Modifying the ID list using config file

Optionally, a configuration file can be written for adjusting the ID list per colony or per time. Currently, the config support remove commands. The file should be text file located in `expdir/session/parameters/ids.cfg`. Each line in the file is interpreted as a command in the format:

```
command colony id from to
```

The time arguments `from` and `to` can be either `start` for the first frame in the experiment, `end` for the last frame in the experiment, `m` followed by a number for the first frame in a movie (e.g. `m3`), 'f' followed by a number for a specific frame in the experiment (e.g. `f4000`), or a combination of a movie and frame for a specific frame in a specific movie (e.g. `m9f1000`).

To remove the id GP for colony C1 for the entire experiment:

```
remove C1 GP start end
```

To remove YY for colony C5 from movie 22 to the end:

```
remove C5 YY m22 end
```

To remove BG for all colonies for frames 20000 to 30000:

```
remove all BG f20000 f30000
```

To remove PP for colony A from frame 100 in movie 4 to frame 2000 in movie 7:

```
remove A PP m4f100 m7f2000
```