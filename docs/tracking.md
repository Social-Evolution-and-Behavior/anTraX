

### Run a batch job 

Once the session is configured, the next step will be to run the blob-tracking step on all the videos in the experiment (see the anTraX publication for details). To start tracking, simply execute the following command in a terminal:

```console
antrax track <experiments> [OPTIONS]
```

The `experiments` argument can be either a full path to an experimental directory, a full path to a text file with a list of experimental directories (all of which will run in parallel), or a full path to a folder that contains one or more experimental directories (all of which will run in parallel). Note that each of the experiments needs to be configured separately before running the batch job. 

The track command accepts the following options:

`--nw <number of workers>`

anTraX will parallelize the tracking jobs by video. By default, it will use two MATLAB workers. Depending on your machine power, this can be changed by using this option. 

`--movlist <list of movie indices>`

By default, anTraX will track all movies in the experiment. This can be changed by using this option. Example for valid inputs incluse: `4`, `3,5,6`, `1-5,7`.

`--session <session name>`

If your experiment contains more than one configured session, anTraX will run on the last configured one. Use this option to choose a session explicitly.

### Checking job progress

Depending on the number and length of video files, tracking jobs can be very long. anTraX will print a report to terminal when a task (tracking of single video) starts/ends. Logs for each task can be found in the experimental directory, under `session/logs/`. Note that depending on your machine settings, the log file might not be updated in real time.

