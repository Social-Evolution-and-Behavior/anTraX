function solve_single_movie(expdir, varargin)

p = inputParser;
addRequired(p,'expdir',@(x) (ischar(x) && isfolder(x)) || isa(x,'trhandles'));
addRequired(p,'m',@(x) isnumeric(x)||ischar(x));
addParameter(p,'colony','')
addParameter(p,'trackingdirname',[]);
addParameter(p,'graph_pairs_maxdepth',[]);

% parse inputs
parse(p,expdir, varargin{:});

m = tonum(p.Results.m);

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

if ~isempty(p.Results.graph_pairs_maxdepth)
    Trck.set_param('graph_pairs_maxdepth',p.Results.graph_pairs_maxdepth);
end

G = Trck.loaddata(m,colony);

solve(G,false,false);

report('I','Saving')
save(G);
report('G','Done')





