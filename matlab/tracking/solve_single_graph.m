function solve_single_graph(expdir,varargin)

p = inputParser;
addRequired(p,'expdir',@(x) (ischar(x) && isfolder(x)) || isa(x,'trhandles'));
addOptional(p,'g',[],@(x) isnumeric(x)||ischar(x));
addParameter(p,'movlist',[],@(x) isnumeric(x));
addParameter(p,'colony','')
addParameter(p,'batchinfo',[]);
addParameter(p,'trackingdirname',[]);
addParameter(p,'graph_pairs_maxdepth',[]);

% parse inputs
parse(p,expdir,varargin{:});

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
        
        report('E',['Unknown colony identifier ', colony])
        return
    
    end

end

if ~isempty(p.Results.g)
   
    groups = Trck.get_solve_groups();
    
    g = p.Results.g;
    
    if ischar(g)
        g = str2double(g);
    end

    if g>length(groups)
        error('g is larger than number of groups')
    else
        movlist = groups{g};
        report('I', ['solving graph from movies',num2str(movlist)])
    end
    
else
    
    movlist = p.Results.movlist;
    
end

if ~all(ismember(movlist,Trck.graphlist))
    error('Some movies dont have a tracklet graph')
end

if ~isempty(p.Results.graph_pairs_maxdepth)
    Trck.set_param('graph_pairs_maxdepth',p.Results.graph_pairs_maxdepth);
end

G = Trck.loaddata(movlist,colony);

solve(G);
report('I','Extracting xy data')
save(G);
export_xy(G);
report('G','Done')





