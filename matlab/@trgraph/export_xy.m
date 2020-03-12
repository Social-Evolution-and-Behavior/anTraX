function export_xy(G,varargin)

p = inputParser;

addRequired(p,'G',@(x) isa(x,'trgraph'));
addParameter(p,'extrafields',{});
addParameter(p,'csv',true);
addParameter(p,'interpolate',true);
addParameter(p,'interpolate_maxd',0.01);
addParameter(p,'interpolate_maxf',300);
addParameter(p,'only_tracklet_table',false,@islogical);
addParameter(p,'hdf',false);
parse(p,G,varargin{:});


if ~G.Trck.get_param('tagged') 
    export_xy_untagged(G, varargin);
end


soft_assigments = G.Trck.get_param('export_use_soft');
too_long_to_be_wrong = G.Trck.get_param('export_too_long_to_be_wrong');

if G.Trck.get_param('geometry_open_boundry')
    too_long_to_be_wrong = inf;
end

if length(G.movlist)>1
    GS = G.split;
    for i=1:length(GS)
        GS(i).export_xy(varargin{:});
    end
    return
end


wdir = [G.Trck.trackingdir,'antdata',filesep];
if ~isfolder(wdir)
    mkdir(wdir)
end

xyfile = G.xyfile; %[wdir,'xy_',num2str(min(G.movlist)),'_',num2str(max(G.movlist)),'.mat'];


if ~p.Results.only_tracklet_table
    eval([G.usedIDs{1},'=[];']);
    save(xyfile,G.usedIDs{1},'-v7.3');
    mat = matfile(xyfile,'Writable',true);
    h5file = [xyfile(1:end-3),'h5'];
end

fi = G.Trck.er.movies_info(G.movlist(1)).fi;
ff = G.Trck.er.movies_info(G.movlist(end)).ff;
nframes = ff-fi+1;

% loading data
if ~p.Results.only_tracklet_table
    report('I',['Loading tracklet data for movie ',num2str(G.movlist)])
    G.set_data;
end

G.node_fi = [G.trjs.fi];
G.node_ff = [G.trjs.ff];

sngl = isSingle(G.trjs);

onboundry = {G.trjs([G.trjs.touching_open_boundry]).name};


tracklet_table = table({},[],[],[],{},[],[],[],'VariableNames',{'ant','from','to','m','tracklet','assigned','single','source'});

for i=1:G.NIDs
    id = G.usedIDs{i};
    xy = nan(nframes,3);
    assigned = G.assigned_ids(:,i);
    true_assigned = assigned;
    % soft
    if soft_assigments
        sg = get_id_subgraph(G,id);
        
        if G.Trck.get_param('geometry_open_boundry')
           
            edges_to_remove = find(ismember(sg.Edges.EndNodes(:,1),onboundry) | ismember(sg.Edges.EndNodes(:,2),onboundry));
            sg = rmedge(sg,edges_to_remove);
            
        end
        
        cc = conncomp(sg,'Type','weak','OutputForm','cell');
        cc = cellfun(@(x) findnode(G.G,x),cc,'UniformOutput',false);
        cc = cc(cellfun(@(x) any(assigned(x))||(G.trjs(x(end)).ff-G.trjs(x(1)).fi+1)>=too_long_to_be_wrong,cc));
        possible = cat(1,cc{:});
        Esg = G.E(:,possible);
        for j=1:length(possible)
            node = possible(j);
            assigned(node) = all(sum(Esg(G.node_fi(node):G.node_ff(node),:),2)==1);
        end
        
    end
    
    trjs = G.trjs(assigned);
    sngli = sngl(assigned);
    asgnd = true_assigned(assigned);
    src = strcmp({trjs.propID},id); 
    
    for j=1:length(trjs)
        trj=trjs(j);
        if ~p.Results.only_tracklet_table
            xy(trj.ti.mf:trj.tf.mf,1:2)=trj.xy;
            if sngli(j)
                xy(trj.ti.mf:trj.tf.mf,3)=trj.ORIENT;
            end
            if ismember('source',p.Results.extrafields)
                xy(trj.ti.mf:trj.tf.mf,3)=src(j);
            end
        end
        % add line to tracklet table
        row = {id,trj.ti.f,trj.tf.f,trj.ti.m,trj.name,asgnd(j),sngli(j),src(j)};
        tracklet_table = [tracklet_table; row];
    end
    
    
    % interpolate
    if p.Results.interpolate && ~p.Results.only_tracklet_table
        allix = 1:size(xy,1);
        nanmask = isnan(xy(:,1));
        
        interpmask = nanmask;
        
        [sqlen,~,sqstart,sqend] = divide2seq(nanmask);
        
        for k=1:length(sqlen)
            if sqstart(k)==1 || sqend(k)==length(allix)
                interpmask(sqstart(k):sqend(k)) = false;
                continue
            end
            dt = sqlen(k);
            dd = sqrt(sum((xy(sqend(k)+1,:) - xy(sqstart(k)-1,:)).^2));
            if dt > p.Results.interpolate_maxf || dd > p.Results.interpolate_maxd
                interpmask(sqstart(k):sqend(k)) = false;
            end
        end
        
        if nnz(interpmask)>0
            xy(interpmask,1) = interp1(allix(~nanmask),xy(~nanmask,1),allix(interpmask));
            xy(interpmask,2) = interp1(allix(~nanmask),xy(~nanmask,2),allix(interpmask));
        end
    end
    
    if ~p.Results.only_tracklet_table
        mat.(id) = xy;
    end
    
    if p.Results.hdf && ~p.Results.only_tracklet_table
        nframes = size(xy,1);
        h5create(h5file,['/data/',id,'/x'],[nframes,1],'Datatype','single');
        h5create(h5file,['/data/',id,'/y'],[nframes,1],'Datatype','single');
        h5create(h5file,['/data/',id,'/or'],[nframes,1],'Datatype','single');
        h5create(h5file,['/data/',id,'/tracklet'],[nframes,1],'Datatype','single');
        
    end
end


% write trackelt table
file = [wdir,'tracklets_table_',num2str(min(G.movlist)),'_',num2str(max(G.movlist)),'.csv'];
writetable(tracklet_table, file);

% write cvs
if p.Results.csv && ~p.Results.only_tracklet_table
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

