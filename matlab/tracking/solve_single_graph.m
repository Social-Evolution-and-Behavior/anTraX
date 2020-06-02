function solve_single_graph(expdir,varargin)

p = inputParser;
addRequired(p,'expdir',@(x) (ischar(x) && isfolder(x)) || isa(x,'trhandles'));
addOptional(p,'g',[],@(x) isnumeric(x)||ischar(x));
addParameter(p,'movlist',[],@(x) isnumeric(x));
addParameter(p,'stitch_step',false);
addParameter(p,'exportxy',true);
addParameter(p,'colony','')
addParameter(p,'batchinfo',[]);
addParameter(p,'trackingdirname',[]);
addParameter(p,'graph_pairs_maxdepth',[]);

% parse inputs
parse(p,expdir,varargin{:});

Trck = trhandles.load(expdir,p.Results.trackingdirname);

if islogical(p.Results.exportxy)
    exportxy = p.Results.exportxy;
elseif isnumeric(p.Results.exportxy)
    exportxy = p.Results.exportxy>0;
elseif ischar(p.Results.exportxy)
    exportxy = strcmp(p.Results.exportxy,'1');
end

if islogical(p.Results.stitch_step)
    stitch_step = p.Results.stitch_step;
elseif isnumeric(p.Results.stitch_step)
    stitch_step = p.Results.stitch_step>0;
elseif ischar(p.Results.stitch_step)
    stitch_step = strcmp(p.Results.stitch_step,'1');
end

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

if isempty(p.Results.movlist) && ~isempty(p.Results.g)
   
    groups = Trck.get_solve_groups();
    
    g = p.Results.g;
    
    if ischar(g)
        g = str2double(g);
    end

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
    error('Some movies dont have a tracklet graph')
end

if ~isempty(p.Results.graph_pairs_maxdepth)
    Trck.set_param('graph_pairs_maxdepth',p.Results.graph_pairs_maxdepth);
end

G = Trck.loaddata(movlist,colony);

solve(G,false,stitch_step);
report('I','Extracting xy data')
save(G);
if exportxy
    export_xy(G,'interpolate',false);
end

report('G','Done')





