function T = parse_prop_config(Trck,varargin)


p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addParameter(p,'command',[],@ischar);

parse(p,Trck,varargin{:});

file = [Trck.paramsdir,'prop.cfg'];

if exist(file,'file')
    T=readtable(file,'FileType','text','ReadVariableNames',false,'Delimiter',' ');
else
    T = [];
    return
end


T.Properties.VariableNames={'command','tracklet','value'};
    
T.command = lower(T.command);

if ~isempty(p.Results.command)
   
    T = T(strcmp(T.command,p.Results.command),:);
    
end

T.value = strrep(T.value,' ','');
