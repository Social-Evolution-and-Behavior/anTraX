function TrackingJob = track_batch(expdir,varargin)

p = inputParser;

addRequired(p,'expdir',@(x) (ischar(x) && isfolder(x)) || isa(x,'trhandles'));
addParameter(p,'movlist','all',@(x) isnumeric(x) || (ischar(x) && strcmp(x,'all')));
addParameter(p,'profile','antrax');
addParameter(p,'NumWorkers',-1);
addParameter(p,'classdir',[]);
addParameter(p,'report',1000,@isnumeric);
addParameter(p,'trackingdirname',[]);

parse(p,expdir,varargin{:});

Trck = trhandles.load(expdir,p.Results.trackingdirname);
expdir = Trck.expdir;

if ~isempty(p.Results.classdir)
    Trck.classdir=p.Results.classdir;
end

%% set profile and number of workers to use:

if isa(p.Results.profile,'parallel.cluster.Local')
    c = p.Results.profile;
elseif ischar(p.Results.profile)
    if ismember(p.Results.profile,parallel.clusterProfiles)
        c = parcluster(p.Results.profile);
    else
        report('W',['parallel profile ',p.Results.profile,' does not exist, using system default'])
        c = parcluster;
    end
else
    c = parcluster;
end

if p.Results.NumWorkers>0
    c.NumWorkers = p.Results.NumWorkers;
    c.NumThreads = 2;
end

report('I',['Using parallel profile ',c.Profile,' with ',num2str(c.NumWorkers),' workers'])

%% create job and tasks

link_fun = functions(Trck.get_param('linking_method'));
TrackingJob = createJob(c,'AttachedFiles',{link_fun.file});
TrackingJob.Name = ['TrackingJob:',expdir];

movlist = p.Results.movlist;
if ischar(movlist) && strcmp(movlist,'all')
    movlist = Trck.movlist;
end

BI.trackingdirname = Trck.trackingdirname;
BI.movlist = movlist;
BI.profile = c.Profile;
BI.NumWorkers = c.NumWorkers;
BI.path_to_antrax = [fileparts(mfilename('fullpath')),'/../../'];

% clear current results
clear_tracking_data(Trck,movlist)

% save a copy of run parameters
Trck.save_params('last_tracking_run');

for m=movlist
    createTask(TrackingJob,@track_single_movie,0,{expdir,'trackingdirname',Trck.trackingdirname,'m',m,'report',p.Results.report,'batchparams',BI},'Name',['movie ',num2str(m)],'CaptureDiary',true);
end
    
%% submit and return

submit(TrackingJob)
report('I',['Job submitted with ',num2str(numel(TrackingJob.Tasks)),' tasks']);


