function pair_search_single_movie(expdir, m, varargin)

p = inputParser;
addRequired(p,'expdir',@(x) (ischar(x) && isfolder(x)) || isa(x,'trhandles'));
addRequired(p,'m',@(x) isnumeric(x)||ischar(x));
addParameter(p,'trackingdirname',[]);
addParameter(p,'graph_pairs_maxdepth',[]);

parse(p,expdir,m, varargin{:});

Trck = trhandles.load(expdir,p.Results.trackingdirname);

if ischar(m)
    m = str2num(m);
end

G = Trck.loaddata(m);

G.load_ids;
G.usedIDs = G.Trck.usedIDs;
G.NIDs = length(G.usedIDs);
G.node_single = G.get_singles;

G.node_fi = [G.trjs.fi];
G.node_ff = [G.trjs.ff];
G.node_noant = ismember({G.trjs.propID},G.Trck.labels.noant_labels);

G.named_pairs = [];

G.get_bottleneck_pairs(false);

npairs = size(G.named_pairs,1);

report('I',['Found ', num2str(npairs),' pairs'])

report('I','Saving')
G.save;
report('G','Finished!')


