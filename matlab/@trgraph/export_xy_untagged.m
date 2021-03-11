function export_xy_untagged(G,varargin)

p = inputParser;

addRequired(p,'G',@(x) isa(x,'trgraph'));
addParameter(p,'extrafields',{'majax'});
addParameter(p,'interpolate',false);
addParameter(p,'csv',true);
parse(p,G,varargin{:});

if length(G)>1
    for i=1:length(G)
        G(i).export_xy_untagged(varargin{:});
    end
    return
end

if length(G.movlist)>1
    GS = G.split;
    for i=1:length(GS)
        GS(i).export_xy_untagged(varargin{:});
    end
    return
end

if G.Trck.Ncolonies==1
    wdir = [G.Trck.trackingdir,'antdata',filesep];
else
    wdir = [G.Trck.trackingdir,'antdata',filesep,G.Trck.colony_labels{G.colony},filesep];
end

    
if ~isfolder(wdir)
    mkdir(wdir)
end

% loading data
report('I',['Loading tracklet data for movie ',num2str(G.movlist)])
G.set_data;

G.node_fi = [G.trjs.fi];
G.node_ff = [G.trjs.ff];

sngl = isSingle(G.trjs);

tracklet_table = table({},[],[],[],{},[],[],[],'VariableNames',{'index','from','to','m','tracklet','assigned','single','source'});

A = table([],[],[],[],[],[],'VariableNames',{'tracklet','frame','xy','area','nants','orient'});

if ismember('majax',p.Results.extrafields)
    A.majax = zeros(0);
end

for i=1:length(G.trjs)
    
    if rem(i,1000)==0
        report('I',['...processed ',num2str(i),'/',num2str(length(G.trjs))])
    end
    
    trj = G.trjs(i);
    
    a.tracklet = repmat(i,[trj.len,1]);
    a.frame = tocol(trj.fi:trj.ff);
    a.xy = trj.xy;
    a.area = trj.rarea;
    a.nants = trj.nants*ones(trj.len,1);
    a.orient = trj.ORIENT;
    
    if ismember('majax',p.Results.extrafields)
        a.majax = trj.MAJAX;
    end
    
    A = [A;struct2table(a)];
    
    % add line to tracklet table
    row = {i,trj.ti.f,trj.tf.f,trj.ti.m,trj.name,false,sngl(i),false};
    tracklet_table = [tracklet_table; row];
    
end

frame = A.frame;
xy = A.xy;
area = A.area;
nants = A.nants;
orient = double(A.orient);
tracklet = A.tracklet;
majax = A.majax;

report('I','Saving...')

% write trackelt table
file = [fileparts(G.xyfile),filesep,'tracklets_table_',num2str(min(G.movlist)),'_',num2str(max(G.movlist)),'_untagged.csv'];
writetable(tracklet_table, file);

xyfile = [G.xyfile(1:end-4),'_untagged.mat'];

save(xyfile,'tracklet','xy','frame','nants','area','orient','-v7.3');

if ismember('majax',p.Results.extrafields)
    save(xyfile,'majax','-v7.3','-append');
end

report('G','Done')



