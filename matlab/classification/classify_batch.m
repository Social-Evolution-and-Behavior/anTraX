function classify_batch(expdir,varargin)

p = inputParser;

addRequired(p,'expdir',@(x) (ischar(x) && isfolder(x)) || isa(x,'trhandles'));
addParameter(p,'movlist','all',@(x) isnumeric(x) || (ischar(x) && strcmp(x,'all')));
addParameter(p,'NumWorkers',-1);
addParameter(p,'usepassed',false,@islogical);
addParameter(p,'path_to_antrax',[fileparts(mfilename('fullpath')),'/../../'],@isfolder)
addParameter(p,'trackingdirname',[]);
addParameter(p,'use_min_conf',true,@islogical);

parse(p,expdir,varargin{:});

Trck = trhandles.load(expdir,p.Results.trackingdirname);
mkdirp(Trck.labelsdir);

%% run classification script


modeldir = ['"',Trck.classdir,'"'];
imagedir = ['"',Trck.imagedir,'"'];

if ischar(p.Results.movlist)
    movlist = 'all';
else
    s = arrayfun(@num2str,p.Results.movlist,'UniformOutput',false);
    movlist = strjoin(s,',');
end

switch computer
    case 'MACI64'
        src_cmd = 'source ~/.bash_profile';
    case 'GLNXA64'
        src_cmd = 'source ~/.profile';
    otherwise
        report('E','Unknown OS')
end

cd_cmd = ['cd ',p.Results.path_to_antrax];

cmd_prefix = 'pipenv run python ./python/classify.py';
classify_cmd = {cmd_prefix,modeldir,imagedir,'--nw',num2str(p.Results.NumWorkers),'--movlist',movlist};

if p.Results.usepassed
    classify_cmd = [classify_cmd,{'--usepassed'}];
end

if ~p.Results.use_min_conf
    classify_cmd = [classify_cmd,{'--dont-use-min-conf'}];
end

classify_cmd = strjoin(classify_cmd);
cmd = strjoin({src_cmd,cd_cmd,classify_cmd},'; ');
system(cmd);


