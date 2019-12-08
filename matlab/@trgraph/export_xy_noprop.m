function export_xy_noprop(G,varargin)

p = inputParser;

addRequired(p,'G',@(x) isa(x,'trgraph'));
addParameter(p,'extrafields',{});
addParameter(p,'csv',false);
parse(p,G,varargin{:});


if ~G.Trck.get_param('tagged') 
    export_xy_untagged(G, varargin);
end

if length(G.movlist)>1
    GS = G.split;
    for i=1:length(GS)
        GS(i).export_xy_noprop(varargin{:});
    end
    return
end


wdir = [G.Trck.trackingdir,'antdata',filesep];
if ~isfolder(wdir)
    mkdir(wdir)
end

xyfile = G.xyfile; %[wdir,'xy_',num2str(min(G.movlist)),'_',num2str(max(G.movlist)),'.mat'];
xyfile = [xyfile(1:end-4),'_noprop.mat'];

eval([G.usedIDs{1},'=[];']);
save(xyfile,G.usedIDs{1},'-v7.3');
mat = matfile(xyfile,'Writable',true);

fi = G.Trck.er.movies_info(G.movlist(1)).fi;
ff = G.Trck.er.movies_info(G.movlist(end)).ff;
nframes = ff-fi+1;

% loading data
report('I',['Loading tracklet data for movie ',num2str(G.movlist)])
G.set_data;

G.node_fi = [G.trjs.fi];
G.node_ff = [G.trjs.ff];

aids = {G.trjs.autoID};

for i=1:G.NIDs
    id = G.usedIDs{i};
    xy = nan(nframes,3);
    trjs = G.trjs(strcmp(aids,id));
           
    for j=1:length(trjs)
        trj=trjs(j);
        xy(trj.ti.mf:trj.tf.mf,1:2)=trj.xy;
        xy(trj.ti.mf:trj.tf.mf,3)=trj.ORIENT;
        if ismember('source',p.Results.extrafields)
            xy(trj.ti.mf:trj.tf.mf,3)=src(j);
        end
    end
    mat.(id) = xy;
end

% write cvs
if p.Results.csv
XY = loadxy(G);
fn = fieldnames(XY);
XY = struct2table(XY);
for i=1:length(fn)
    id = fn{i};
    varnames{i}={[id,'_X'],[id,'_Y'],[id,'_OR']};
end
XY = splitvars(XY,fn,'NewVariableNames',varnames);
csvfile = [xyfile(1:end-3),'csv'];
writetable(XY,csvfile);
end

