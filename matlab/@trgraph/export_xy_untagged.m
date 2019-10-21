function export_xy_untagged(G,varargin)

p = inputParser;

addRequired(p,'G',@(x) isa(x,'trgraph'));
addParameter(p,'extrafields',{});
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

%sngl = isSingle(G.trjs);

A = table([],[],[],[],[],'VariableNames',{'frame','xy','area','nants','orient'});

for i=1:length(G.trjs)
    
    if rem(i,1000)==0
        report('I',['...processed ',num2str(i),'/',num2str(length(G.trjs))])
    end
    
    trj = G.trjs(i);
    
    a.frame = [tocol(trj.fi:trj.ff);nan];
    a.xy = [trj.xy;nan,nan];
    a.area = [trj.rarea;nan];
    a.nants = [trj.nants*ones(trj.len,1);nan];
    a.orient = [trj.ORIENT;nan];
    
    A = [A;struct2table(a)];
    
end

frame = A.frame;
xy = A.xy;
area = A.area;
nants = A.nants;
orient = A.orient;

report('I','Saving...')
save(G.xyfile,'xy','frame','nants','area','orient','-v7.3');
report('G','Done')



