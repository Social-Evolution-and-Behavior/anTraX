function T = parse_time_config(Trck,varargin)


p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addParameter(p,'command','',@ischar);
addParameter(p,'colony',[]);

parse(p,Trck,varargin{:});

file = [Trck.paramsdir,'ids.cfg'];

if exist(file,'file')
    T=readtable(file,'FileType','text','ReadVariableNames',false,'Delimiter',' ');
else
    T = [];
    return
end

if Trck.get_param('geometry_multi_colony')

    T.Properties.VariableNames={'command','colony','id','from','to'};
    
    
elseif size(T,2)==5
    
    T.Properties.VariableNames={'command','colony','id','from','to'};
    T.colony = [];
    
elseif size(T,2)==4
    
    T.Properties.VariableNames={'command','id','from','to'};

end



for i=1:size(T,1)
   
    fromstr = T.from{i};
    fromstr = replace(fromstr,' ','');
    
    if strcmp(fromstr,'start')
        
        ti(i) = trtime(Trck,1);
        
    elseif fromstr(1)=='f'
        
        ti(i) = trtime(Trck,str2num(fromstr(2:end)));
        
    elseif fromstr(1)=='m' && ~contains(fromstr,'f')
        
        ti(i) = trtime(Trck,str2num(fromstr(2:end)));
        
    elseif fromstr(1)=='m' && contains(fromstr,'f')
        
        s = strsplit(fromstr(2:end),'f');
        m = str2num(s{1});
        mf = str2num(s{2});
        ti(i) = trtime(Trck,m,mf);
        
    else
        
        error('Wrong format in time config file (from string)');
        
    end
    
    
    tostr = T.to{i};
    tostr = replace(tostr,' ','');
    
    if strcmp(tostr,'end')
        
        tf(i) = trtime(Trck,Trck.er.movies_info(end).ff);
        
    elseif tostr(1)=='f'
        
        tf(i) = trtime(Trck,str2num(tostr(2:end)));
        
    elseif tostr(1)=='m' && ~contains(tostr,'f')
        
        m = str2num(tostr(2:end));
        f = Trck.er.movies_info(m).ff;
        tf(i) = trtime(Trck,f);
        
    elseif tostr(1)=='m' && contains(tostr,'f')
        
        s = strsplit(tostr(2:end),'f');
        m = str2num(s{1});
        mf = str2num(s{2});
        tf(i) = trtime(Trck,m,mf);
        
    else
        
        error('Wrong format in time config file (to string)');
        
    end
    
    
end


T.from = tocol(ti);
T.to = tocol(tf);
T.command = lower(T.command);
T.id = strrep(T.id,' ','');

if ~isempty(p.Results.colony) && ismember('colony',T.Properties.VariableNames)
    
   if isnumeric(p.Results.colony)
       c = Trck.colony_labels{p.Results.colony};
   else
       c = p.Results.colony;
   end
    
   T = T(strcmp(T.colony,c) |  strcmp(T.colony,'all'),:);
   T.colony = []; 
    
end

if ~isempty(p.Results.command)
    
   T = T(strcmp(T.command,p.Results.command),:);
   T.command = []; 
    
end



