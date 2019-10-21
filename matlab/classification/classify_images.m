function out=classify_images(expdir,varargin)

p = inputParser;

addRequired(p,'expdir',@(x) (ischar(x) && isfolder(x)) || isa(x,'trhandles'));
addRequired(p,'images',@(x) isnumeric(x) || isa(x,'tracklet'));
addParameter(p,'NumWorkers',-1);
addParameter(p,'path_to_catt',[fileparts(mfilename('fullpath')),'/../../'],@isfolder)
addParameter(p,'trackingdirname',[]);

parse(p,expdir,varargin{:});

Trck = trhandles.load(expdir,p.Results.trackingdirname);
Trck.save_params;
labelsfile = [Trck.paramsdir,'labels.csv'];

%% run classification script


modeldir = ['"',Trck.classdir,'"'];

if isa(p.Results.images,'tracklet')
    images = p.Results.images.get_image('all');
else
    images = p.Results.images;
end

% prepate tmp images file 
f1 = [tempname,'.mat'];
f2 = [tempname,'.mat'];
save(f1,'images','-v7.3');


switch computer
    case 'MACI64'
        src_cmd = 'source ~/.bash_profile';
    case 'GLNXA64'
        src_cmd = 'source ~/.profile';
    otherwise
        report('E','Unknown OS')
end

cd_cmd = ['cd ',p.Results.path_to_catt];

cmd_prefix = 'pipenv run python ./python/classify_images.py';
classify_cmd = {cmd_prefix,modeldir,labelsfile,f1,f2,'--nw',num2str(p.Results.NumWorkers)};
classify_cmd = strjoin(classify_cmd);
cmd = strjoin({src_cmd,cd_cmd,classify_cmd},'; ');
system(cmd);

% read output from tmp file
A = h5info(f2);
vars = {A.Datasets.Name};
for i=1:length(vars)
    out.(vars{i}) = h5read(f2,['/',vars{i}]);
end

f3=fopen([Trck.classdir,filesep,'classes.csv']);
out.classes = textscan(f3,'%s');
out.classes=out.classes{1}';
out.y=out.y';
fclose(f3);

delete(f1)
delete(f2)

