function create_tracking_directory(A)

trdir = [A.expdir,filesep,A.trackingdirname,filesep];

mkdirp(trdir);
mkdirp([trdir,'images']);
mkdirp([trdir,'tracklets']);
mkdirp([trdir,'graphs']);
mkdirp([trdir,'parameters']);
