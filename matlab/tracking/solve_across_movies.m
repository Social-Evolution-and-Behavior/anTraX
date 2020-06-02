function solve_across_movies(expdir,varargin)

p = inputParser;
addRequired(p,'expdir',@(x) (ischar(x) && isfolder(x)) || isa(x,'trhandles'));
addOptional(p,'g',[],@(x) isnumeric(x)||ischar(x));
addParameter(p,'movlist',[],@(x) isnumeric(x));
addParameter(p,'colony','')
addParameter(p,'trackingdirname',[]);

% parse inputs
parse(p,expdir,varargin{:});

g = tonum(p.Results.g);

Trck = trhandles.load(expdir,p.Results.trackingdirname);

colony = p.Results.colony;

if Trck.get_param('geometry_multi_colony')
    
    if isempty(colony)
        
        report('E','Colony argument is missing for multi colony experiment')
        return
        
    elseif isnumeric(colony)
        
        try
            colony = Trck.colony_labels{colony};
        catch
            report('E','Bad colony number')
            return
        end
        
    elseif ~ismember(colony,Trck.colony_labels)
        
        try
            colony = str2num(colony);
            colony = Trck.colony_labels{colony};
        catch
            report('E',['Unknown colony identifier ', colony])
            return
        end

    end

end

if isempty(p.Results.movlist) && ~isempty(g)
   
    groups = Trck.get_solve_groups();
    
    if g>length(groups)
        error('g is larger than number of groups')
    else
        movlist = groups{g};
        report('I', ['solving graph from movies ',num2str(movlist(1)), '-',num2str(movlist(end))])
    end
    
else
    
    movlist = p.Results.movlist;
    
end

if ~all(ismember(movlist,Trck.graphlist))
    error('Some movies do not have a tracklet graph')
end

G = Trck.loaddata(movlist,colony);

solve(G,false,true);
report('I','Saving')
save(G);
report('G','Done')





