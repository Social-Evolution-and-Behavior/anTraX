## Run tracking


Once the session is configured, the next step will be to run the blob tracking on all the videos in the experiment.	

### Run a batch job in MATLAB
The recommended way to run anTraX is in batch mode. In this mode, a parallel job is created with a seperate task for each video in the experiment. It is sometime usefull to define a parallel profile named `antrax` in your MATLAB environment and configure it for your liking. If such a profile exist, anTraX will use it to run its jobs. Otherwise, it will use the system default profile. 

To run a job with all videos:

```matlab
J=track_batch(Trck);
```

To run a job with a partial list of movie numbers:

```matlab
J=track_batch(Trck,'movlist',<list of video numbers>);
```

To check the progress of the tracking job, use the built-in job monitor in the MATLAB IDE, or look at the task table by typing:

```matlab
J.Tasks
```



### Run interactively 

For experiments with a single video file, or for debugging purposes, it is possible to track a single video interactively in the current MATLAB session:

To track an entire video:
```matlab
track_single_movie(Trck,m);
```

To track a limited range of frames (`fi` and `ff` are start and end frame numbers *relative to the start of the experiment*):

```matlab
track_single_movie(Trck,'from',fi,'to',ff);
```

### Run with MATLAB Runtime engine

TBD

### Run on HPC environment 

TBD
