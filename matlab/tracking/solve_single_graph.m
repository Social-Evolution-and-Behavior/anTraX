function solve_single_graph(expdir,varargin)

p = inputParser;
addRequired(p,'expdir',@(x) (ischar(x) && isfolder(x)) || isa(x,'trhandles'));
addParameter(p,'movlist',[],@(x) isnumeric(x));
addParameter(p,'colony','')
addParameter(p,'batchinfo',[]);
addParameter(p,'trackingdirname',[]);
addParameter(p,'NumWorkers',2);
addParameter(p,'graph_pairs_maxdepth',[]);

% parse inputs
parse(p,expdir,varargin{:});

Trck = trhandles.load(expdir,p.Results.trackingdirname);

colony = p.Results.colony;

if Trck.get_param('geometry_multi_colony') && isempty(colony)
    report('E','Colony argument is miising for multi colony experiment')
    return
elseif Trck.get_param('geometry_multi_colony') && ~ismember(colony,Trck.colony_labels)
    report('E','Unknown colony identifier')
    return
end

if ~isempty(p.Results.graph_pairs_maxdepth)
    Trck.set_param('graph_pairs_maxdepth',p.Results.graph_pairs_maxdepth);
end

G = Trck.loaddata(p.Results.movlist,colony);
G.NumWorkers = p.Results.NumWorkers;

solve(G);
report('I','Extracting xy data')
save(G);
export_xy(G);
report('G','Done')





