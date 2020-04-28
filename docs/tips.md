### Marking insects

* Choose colors that are easily separated in RGB space. As a rule of thumb, colors that are easily separated by a human eye in the video will result in better tracking (surprise!). The color set Blue, Green, Orange, Pink, and Yellow usually results in good accuracy.

* It is important to make sure that all tags are visible to the camera for a large part of the frames, at least when an ant is on the move. For that reason, placing tags one behind the other is preferable over side-by-side tagging . 

* It is not advised to use a variable number of tags per ant (for example, using "no tag" as an additional color). As tags are often not visible (e.g., when an ant is grooming or on its side), this can lead to a high error rate (i.e. obscured tag is identified as a no-tag ID).

* It is possible to use symmetric color combinations (e.g., Blue-Green and Green-Blue) in the same experiment. However, note that in that case, an asymmetry in the ant appearance in the image is necessary for good classification. For example, for *O. biroi*, a thorax tag and abdomen tag will work nicely, assuming the head and the antennae are breaking the image symmetry (don't paint the head!).    

### Recording videos

* The program is designed to identify dark ants on a light background. The better the contrast, the easier it is to segment the ants from their background. 

* It is recommended to tune the camera, especially the brightness, contrast, and saturation levels, to make sure tag colors are maximally distinguishable. A bit of over saturation is usually advised. 

* As the software segments the image using background subtraction, it is important to make sure the image is stable throughout the experiment. Particularly, try to minimize camera movement, arena movements, and illumination fluctuations. 

* Sometimes, it is necessary to pause the experiment and to take care of the experimental colonies. It is recommended to start a new video subdirectory to hold movies if the arenas cannot be returned to their exact position relative to the camera, or if there is a change in the arena that can result in a changing background. Backgrounds can be created separately for each subdirectory. 

* Video resolution should be high enough to identify the color tags. As a rule of thumb, a tag size of at least 5x5 pixels is recommended. 

* Video frame rate should be high enough to make sure ant blobs in consecutive frames overlap considerably. For experiments with the clonal raider ant *O. biroi*, a framerate of 10 fps is enough.

### Computer configuration and parallel execution 

* A tracking job will typically use around 125-150% CPU. Therefore, it is recommended to set the number of MATLAB workers to about 0.5-0.75 of the number of threads supported by your machine. It is also recommended to have at least 2GB of RAM and 4GB of swap per worker. 

* Tracking jobs are usually long. It is advised to use a desktop computer or workstation and not a laptop computer. Make sure to turn off auto sleep on the computer. 

### Tracking settings and parameters

* What is a good background

* median vs max

* What is a good ROI mask

* Good segmentation 

* Why single ant threshold is important


### Training and classification

* Choosing good examples for training a classifier is an art. On the one hand, it is a good practice to span the space of possible presentations of the ants, and choose "atypical" images. On the other hand, as this space is huge, we are practically guaranteed to be in an under-sampled regime, so it is better not to use examples in ambiguous areas of the image space. As a rule of thumb, don't use images that are not easily identifiable for a human. 
  
* If you see a systematic classification error between two IDs, especially if there is no clear visual reason for this error, it is likely that you have some contamination of the training set. Try checking the example directory of the classified label and look for examples that belong to the actual ant ID. Delete them and retrain the classifier.

* Neural networks are best trained using negative examples. Otherwise, they will produce high rate of false positives in cases where none of the known labels exist. In our case, this is represented by the "Unknown" class (and the "Multi" class if it is included). It is important to add as many examples as possible to this class. Good images are those that a human cannot identify at all. Tracklets labeled as "Unknown" are left for the propagation algorithm to assign.

* Why are some tracklets identified as "Unknown" although they are very obvious to recognize? This might be due to a few possible reasons. It might be just a sampling issue: as short tracklets are, well, short, maybe their images happen to be in a region of image space not covered by the training set (remember that assignments requires high confidence, so even though the blob classifier assigns it correctly, the algorithm removes the assignment due to low confidence). In that case, adding these images to the training set will help future rounds of classification.  Alternatively, the training set is contaminated, so a conflicting example reduces the confidence of the classifier (it is always recommended to check the set every now and then). 

### ID propagation 


### Debugging and fixing the tracking

### Working with xy trajectories

* 