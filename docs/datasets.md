

As described in the anTraX publication, the software was benchmarked using 9 different datasets, representing a variety of possible use cases. All datasets, including the anTraX configuration files used to track them are [available for download](https://zenodo.org/record/3740547).





![datasets table 1](images/datasets_table1.png)


![datasets table 2](images/datasets_table2.png)


### Dataset J16

A colony of 16 clonal raider ants (*O. biroi*) tracked for 24 hours. This videos in this example are taken with a simple webcam, using low resolution (10 pix/mm, representing around 5x5 pixels per tag).

![J16](images/J16.png)

### Dataset A36

A colony of 36 clonal raider ants (*O. biroi*) tracked for 24 hours. The videos in this example are taken with FLIR-Flea3 12MP camera at a relatively high resolution (25 pix/mm), enabling the program to distinguish between more colors, and to augment the basic tracking with pose tracking using DeepLabCut (see anTraX publication).

![A36](images/A36.png)


### Dataset V25

A colony of 25 clonal raider ants (*O. biroi*) tracked for 6 hours. The videos in this example are taken with a simple webcam, but using higher resolution than in dataset J16. Although the resolution is high, the image quality in this example is reduced by an acrylic cover placed between the ants and the camera. This dataset is an example for tracking an open boundry arena, where ants can leave and enter through a specific part of the boundry.

![V25](images/V25.png)


### Dataset G6X16

This dataset is an example for tracking multiple colonies within the same video (6 colonies of 16 *O. biroi* ants). In addition, the image quality in this example is reduced by the low contrast between the ants and the background, the petri dish covers, and light reflections from those covers.

![G6X16](images/G6X16.png)


### Dataset T10

A colony of 10 *Temnothorax nylanderi* ants recorded for 6 hours using a webcam. The ants are marked with 4 tags each. 

![T10](images/T10.png)


### Dataset C12

A colony of 12 *Camponotous fellah* ants recorded for 6 hours using a webcam. The ants are marked with 3 tags each. Although the ants are big in this example, their high velocity compared to the frame rate poses a challange and leads to an increased rate of linking errors. In addition, two ants are marked with the same color combination, but the algorithm was able to individually track them by using slight appearance variations. 

![C12](images/C12a.png)


### Dataset C32

A colony of 12 *Camponotous* ants (unidentified species) recorded for 24 hours. The ants are marked with 3 tags each. One ant (a virgin queen) is unmarked and identified by the classifier by other appearance markers (size, wings).

![C32](images/C32.png)


### Dataset D7

A group of 7 fruit flies marked by one tag each and recorded for 1 hour.

![D7](images/D7.png)


### Dataset D16

A group of 16 fruit flies marked by two tags each and recorded for 5 hours.

![D16](images/D16.png)


