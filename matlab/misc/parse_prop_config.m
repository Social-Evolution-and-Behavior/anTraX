function T = parse_prop_config(Trck,varargin)


p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));

parse(p,Trck,varargin{:});

file = [Trck.paramsdir,'prop.cfg'];

if exist(file,'file')
    T=readtable(file,'FileType','text','ReadVariableNames',false,'Delimiter',' ');
else
    T = [];
    return
end


T.Properties.VariableNames={'command','tracklet','id'};
    
T.command = lower(T.command);
T.id = strrep(T.id,' ','');
