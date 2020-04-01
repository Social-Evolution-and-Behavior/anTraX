
### Propagating IDs on tracklet graphs

To run propagation in batch mode:

```console
antrax solve <experiments> [OPTIONS]
```

The `experiments` argument can be either a full path to an experimental directory, a full path to a text file with a list of experimental directories (all of which will run in parallel), or a full path to a folder that contains one or more experimental directories (all of which will run in parallel).


The solve command accepts the following options:

`--nw <number of workers>`

anTraX will parallelize the tracking by video. By default, it will use two MATLAB workers. Depending on your machine power, this can be changed by using this option. 

`--glist <list of graph indices>`

By default, anTraX will track all graphs in the experiment. This can be changed by using this option. Graph indices are an enumeration of movie groups according to the options set in the session configuration. Example for valid inputs include: `4`, `3,5,6`, `1-5,7`.

`--clist <list of colony indices>`

If the experiment is multi-colony, by default, anTraX will run all colonies in the experiment. This can be changed by using this option. Colony indices are 1 to the number of colonies. Example for valid inputs include: `4`, `3,5,6`, `1-5,7`.


`--session <session name>`

If your experiment contains more than one configured session, anTraX will run on the last configured one. Use this option to choose a session explicitly.


### Using the graph explorer to view and debug ID assignments

To launch:

```console
antrax graph-explorer <expdir> [--session]
```

![Graph Explorer](images/graph-explorer1.png)
