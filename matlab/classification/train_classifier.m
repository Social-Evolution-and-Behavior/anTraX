function train_classifier(classdir,varargin)


if isa(classdir,'trhandles')
    Trck = classdir;
    classdir = Trck.classdir;
end

p = inputParser;

addRequired(p,'classdir',@isfolder);
addParameter(p,'path_to_catt',[fileparts(mfilename('fullpath')),'/../../'],@isfolder)
addParameter(p,'from_scratch',false,@islogical);
addParameter(p,'ne',5,@isnumeric);
addParameter(p,'target_size',[],@isnumeric);
parse(p,classdir,varargin{:});

classdir = ['"',classdir,'"'];

switch computer
    case 'MACI64'
        src_cmd = 'source ~/.bash_profile';
    case 'GLNXA64'
        src_cmd = 'source ~/.profile';
    otherwise
        report('E','Unknown OS')
end

cd_cmd = ['cd ',p.Results.path_to_catt];

cmd_prefix = 'pipenv run python ./python/train.py';
train_cmd = {cmd_prefix,classdir};

if p.Results.from_scratch
    train_cmd = [train_cmd,{'--from-scratch','--ne','100'},{'--verbose','2'}];
else
    train_cmd = [train_cmd,{'--ne',num2str(p.Results.ne)},{'--verbose','2'}];
end

if ~isempty(p.Results.target_size)
    train_cmd = [train_cmd,{'--target_size',p.Results.target_size}];
end

train_cmd = strjoin(train_cmd);
cmd = strjoin({src_cmd,cd_cmd,train_cmd},'; ');
system(cmd);
