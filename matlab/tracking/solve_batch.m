function SolvingJob = solve_batch(expdir,varargin)

p = inputParser;

addRequired(p,'expdir',@(x) (ischar(x) && isfolder(x)) || isa(x,'trhandles'));
addParameter(p,'movlist','all',@(x) isnumeric(x) || (ischar(x) && strcmp(x,'all')));
addParameter(p,'groupBy','subdir');
addParameter(p,'movie_groups',[]);
addParameter(p,'profile','antrax');
addParameter(p,'trackingdirname',[]);

addParameter(p,'NumWorkers',-1);

parse(p,expdir,varargin{:});

Trck = trhandles.load(expdir,p.Results.trackingdirname);

expdir = Trck.expdir;

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


%% cretae movie groups

movlist = p.Results.movlist;
if ischar(movlist) && strcmp(movlist,'all')
    movlist = Trck.graphlist;
end

if isempty(movlist)
    report('E','movlist is empty!')
    SolvingJob = [];
    return
end

SolvingJob=[];

switch p.Results.groupBy
    
    case 'subdir'
        subdirs = {Trck.er.movies_info(movlist).dir};
        g = findgroups(subdirs);
        
    case 'movie'
        g = findgroups(movlist);
        
    case 'all'
        g = ones(size(movlist));
        
    case 'manual'
        g = p.Results.movies_groups;
        
        if length(g)~=length(movlist)
            report('E','With manual grouping, you must give a grouping vector equal in length to the munber of movies');
            return
        end
        
    otherwise
        report('E','unknown grouping option')
        return
end

for i=1:length(unique(g))
    mgroups{i} = movlist(g==i);
end

%% create job and tasks

SolvingJob = createJob(c);
SolvingJob.Name = ['SolvingJob:',expdir];

BI.mgroups = mgroups;
BI.movlist = movlist;

for i=1:length(unique(g))
    if Trck.get_param('geometry_multi_colony')
        for j=1:Trck.Ncolonies
            c = Trck.colony_labels{j};
            createTask(SolvingJob,@solve_single_graph,0,{expdir,'trackingdirname',Trck.trackingdirname,'movlist',mgroups{i},'colony',c,'batchinfo',BI},'Name',['colony ',c,' movies ',num2str(mgroups{i})],'CaptureDiary',true);
        end
    else
        createTask(SolvingJob,@solve_single_graph,0,{expdir,'trackingdirname',Trck.trackingdirname,'movlist',mgroups{i},'batchinfo',BI},'Name',['movies ',num2str(mgroups{i})],'CaptureDiary',true);
    end
end
    



%% submit and return

submit(SolvingJob)
report('I',['Job submitted with ',num2str(numel(SolvingJob.Tasks)),' tasks']);








