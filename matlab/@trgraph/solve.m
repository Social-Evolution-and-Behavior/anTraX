function solve(G, skip_pairs_search)

if nargin<2
    skip_pairs_search = false;
end

report('I','Loading ids')
G.load_ids;
G.usedIDs = G.Trck.usedIDs;
G.NIDs = length(G.usedIDs);

report('I','Finding single ant nodes')
G.node_single = G.get_singles;

if isempty(G.node_fi)  
    report('I','Some preperations')
    G.node_fi = [G.trjs.fi];
    G.node_ff = [G.trjs.ff];
    G.node_noant = ismember({G.trjs.propID},G.Trck.labels.noant_labels);
end


if isempty(G.pairs)
    G.get_bottleneck_pairs(skip_pairs_search);
end

% step 0: reset
report('I','Resetting graph id assigments')
reset(G);

% step 1: filter out non-ant tracklets
report('I','Filtering out tracklets identified as non-ant')
nonant_trjs = G.trjs(G.node_noant);
nonant_nodes = find(G.node_noant);
finalize(G,nonant_nodes);
report('I',['...',num2str(length(nonant_nodes)),' tracklets classified as no-ant were filtered'])

% filter out unconnected short small tracklet
noant_nodes = indegree(G.G)==0 & outdegree(G.G)==0 & cat(1,G.trjs.len)<=3 & cat(1,G.trjs.nanmeanrarea)<=G.Trck.get_param('thrsh_meanareamin');
noant_nodes = find(noant_nodes);
noant_nodes = noant_nodes(~ismember({G.trjs(noant_nodes).autoID},G.usedIDs));
finalize(G,noant_nodes);
report('I',['...',num2str(nnz(noant_nodes)),' short, unconnected and unidentified tracklets were filtered'])

% step 1.5: apply temporal window for ids ??
if G.Trck.get_param('graph_apply_temporal_window')
    
    cmd = parse_time_config(G.Trck,'colony',G.colony,'command','remove');
    
    for i=1:size(cmd,1)
        
        idix = strcmp(cmd.id{i},G.usedIDs);
        
        fi = cmd.from(i).f;
        ff = cmd.to(i).f;
        
        nodes = any(G.E(fi:ff,:),1);
        
        G.possible_ids(nodes,idix) = false;
    end
    
end


% step 1.9: apply manual config
G.aux.cfg_src_nodes=[];
if G.Trck.get_param('graph_apply_manual_cfg') && exist([G.Trck.paramsdir,'prop.cfg'],'file')
    
    
    cmd = parse_prop_config(G.Trck);
    
    for i=1:size(cmd,1)
        
        
        tracklet = cmd.tracklet{i};
        
        if ~ismember(tracklet,G.Nodes.Name)
            continue
        end
        
        node = find(strcmp(tracklet,G.Nodes.Name));
        idix = strcmp(cmd.id{i},G.usedIDs);
        if ~any(idix)
            continue
            
        end
        
        switch cmd.command{i}
            
            case 'assign'
                assign(G,node,idix);
                G.aux.cfg_src_nodes = [G.aux.cfg_src_nodes;node];
            case 'eliminate'
                eliminate(G,node,find(idix));
            otherwise
                error('wrong command')
        end
        
    end
    
    
end


% step 2: propagate src tracklets
report('I','Propagating ids from src tracklets')
src_trjs = G.trjs(ismember({G.trjs.propID},G.Trck.usedIDs) & torow(G.node_single));
src_score = arrayfun(@(x) x.propScore,src_trjs);

ix = argsort(src_score,'descend');
src_score = src_score(ix);
src_trjs = src_trjs(ix);
src_ids  = {src_trjs.propID};
src_idix = cellfun(@(x) find(strcmp(x,G.usedIDs)),src_ids);
src_nodes = nodes_from_trjs(G,src_trjs);
G.aux.src_nodes=src_nodes;
G.aux.src_score=src_score;
G.aux.contradictions=0;
G.aux.contradicting_src_nodes=[];
n=0;
for i=1:length(src_nodes)
    if ~rem(i,1000)
        report('I',['    ...finished ',num2str(i),'/',num2str(length(src_nodes))]);
    end
    ni = assign(G,src_nodes(i),src_idix(i));
    n = n + ni;
end

propagate_all(G);
filter_by_cc(G);

cnt = 1;
while true
    cnt=cnt+1;
    n = propagate_all(G);
    
    if n==0
        break
    end
    
    n = filter_by_cc(G);
    
    if n==0
        break
    end
    
    if G.Trck.get_param('graph_max_iterations')>0 && cnt>=G.Trck.get_param('graph_max_iterations')
        report('I','max iteration reached, stopping');
        break
    end
    
end

% finalize all nodes with poss==assigned
G.finalized = all(G.possible_ids==G.assigned_ids,2);



report('I','Assigning ids to tracklets')


end



function n = filter_by_cc(G)

report('I','Filtering by connected componnets')

n=0;

for i=1:G.NIDs
    
    id = G.usedIDs{i};
    idix = i;
    report('I',['...working on ',id])
    
    
    % get the subraph and connected components of id
    sg = get_id_subgraph(G,id);
    if sg.numnodes==0
        report('W',['......No nodes for ',id,', skipping'])
        continue
    end
    
    cc = conncomp(sg,'Type','weak','OutputForm','cell');
    cc = cellfun(@(x) findnode(G.G,x),cc,'UniformOutput',false);
    cc_size = cellfun(@numel,cc);
    
    
    % filter cc by size
    min_cc_size = G.Trck.get_param('graph_min_cc_size');
    if min_cc_size>1
        to_filter = cc_size<min_cc_size;
        n = n + nnz(to_filter);
        eliminate_cc(G,cc(to_filter),idix);
        cc = cc(~to_filter);
        report('I',['......filtered ',num2str(nnz(to_filter)),'small cc''s'])
    end
    
    
    clear cc_score
    for j=1:length(cc)
        
        % cc rank is
        % duration*percent_assigned*num_of_sources*max_source_score
        
        duration = max(G.node_ff(cc{j}))-min(G.node_fi(cc{j}))+1;
        percent_assigned = 0.1 + mean(G.assigned_ids(cc{j},idix));
        cc_sources = intersect(cc{j},G.aux.src_nodes);
        cc_source_cfg = intersect(cc{j},G.aux.cfg_src_nodes);
        num_of_sources =  0.1 + numel(cc_sources) + numel(cc_source_cfg);
        
        if num_of_sources>=1 && isempty(cc_source_cfg)
            max_src_score = max(G.aux.src_score(ismember(G.aux.src_nodes,cc{j})));
        elseif num_of_sources>=1
            max_src_score = 1000;
        else
            max_src_score = 0.1;
        end
        
        cc_score(j) = duration * percent_assigned * num_of_sources * max_src_score;
        
    end
    
    
    
    
    
    report('I',['......found ',num2str(length(cc)),' cc''s '])
    
    
    
    % filter overlapping cc
    % cc_score = cellfun(@(x) max([G.trjs(x).ff])-min([G.trjs(x).fi]+1),cc);
    no_src_node = cellfun(@(x) isempty(intersect(x,G.aux.src_nodes)) && isempty(intersect(x,G.aux.cfg_src_nodes)),cc);
    cc_score(no_src_node) = cc_score(no_src_node)-max(cc_score(no_src_node));
    sortix = argsort(cc_score,'descend');
    cc = cc(sortix);
    cc_score = cc_score(sortix);
    ccol = cc_overlapping(G,cc);
    
    to_keep = false(size(cc));
    to_keep(1) = true;
    for j=2:length(cc)
        
        ccolj = find(ccol(:,j) & tocol(to_keep));
        
        if isempty(ccolj)
            to_keep(j)=true;
        elseif isscalar(ccolj)
            
            % solve cases where the overlapping is weak, and
            % can be solved by removing not-source nodes
            
            
            % make an effort only if this cc has a source node!
            if isempty(intersect(cc{j},G.aux.src_nodes))
                continue
            end
            
            % find overlapping nodes
            ol_nodes_this_cc = overlapping_with_cc(G,cc{j},cc{ccolj});
            ol_nodes_ol_cc = overlapping_with_cc(G,cc{ccolj},cc{j});
            
            % keep those from the highest score cc
            eliminate(G,ol_nodes_this_cc,idix,true);
            
            
            % make sure none of them is source
            %if any(ismember(ol_nodes_this_cc,G.aux.src_nodes)) || any(ismember(ol_nodes_ol_cc,G.aux.src_nodes))
            %   report('W','source node overlapping problem!')
            %end
            
            % keep those that are closer to a source node
            %                         src_nodes_this_cc = intersect(cc{j},G.aux.src_nodes);
            %                         src_nodes_ol_cc = intersect(cc{ccolj},G.aux.src_nodes);
            %
            %                         dist_to_src_this_cc = node_dist(G,src_nodes_this_cc,ol_nodes_this_cc);
            %                         dist_to_src_ol_cc = node_dist(G,src_nodes_ol_cc,ol_nodes_ol_cc);
            %
            %                         if dist_to_src_this_cc<dist_to_src_ol_cc
            %                             eliminate(G,src_nodes_ol_cc,idix,true);
            %                         else
            %                             eliminate(G,src_nodes_this_cc,idix,true);
            %                         end
            
            %report('I','Saved a cc!')
            
            % keep the cc
            to_keep(j)=true;
            
        end
    end
    n = n + nnz(~to_keep);
    eliminate_cc(G,cc(~to_keep),idix);
    cc = cc(to_keep);
    report('I',['......filtered ',num2str(nnz(to_keep==0)),' cc''s'])
    
    
    
    % prune multiple src/sink nodes
    n=0;
    for j=1:length(cc)
        n = n + cc_prune(G,cc{j},idix);
    end
    report('I',['......pruned ',num2str(n),' nodes'])
    
    
end


end




function n = assign(G,node,id)

if islogical(id)
    id = find(id);
end

% assign multiple ids
if length(id)>1
    n=0;
    for i=1:length(id)
        n = n + assign(G,node,id(i));
    end
    return
end


n = 0;

% assign to self

if  ~G.assigned_ids(node,id) && G.possible_ids(node,id)
    G.assigned_ids(node,id) = true;
    n = n + 1;
elseif ~G.assigned_ids(node,id) && ~G.safe_prop_mode
    G.assigned_ids(node,id) = true;
    n = n + 1;
elseif ~G.possible_ids(node,id)
    if ~isfield(G.aux,'contradictions')
        G.aux.contradictions = 0;
        G.aux.contradicting_src_nodes = [];
    end
    
    G.aux.contradictions = G.aux.contradictions+1;
    G.aux.contradicting_src_nodes(end+1,1) = node;
    return
else
    return
end

% if single ant, eliminate all other ids and finalize
if G.node_single(node)
    finalize(G,node);
end

% eliminate id from overlapping trjs
eliminate(G,overlapping(G,node),id);

% propogate
nprop = propagate(G,node,id);
n = n + nprop;

end

function eliminate(G,nodes,ids,force)
for i=1:length(ids)
    id = ids(i);
    iscont = false(size(nodes));
    if nargin<4 || force==false
        iscont = G.assigned_ids(nodes,id);
        %G.aux.contradictions = G.aux.contradictions + nnz(iscont);
        %G.aux.contradicting_src_nodes = [G.aux.contradicting_src_nodes;find(iscont)];
    end
    G.possible_ids(nodes(~iscont),id) = false;
    G.assigned_ids(nodes(~iscont),id) = false;
end
end

function eliminate_cc(G,cc,id)

% when eliminating id from cc, it runs over previous assigments
nodes = cat(1,cc{:});
G.possible_ids(nodes,id) = false;
G.assigned_ids(nodes,id) = false;

end

function n = propagate(G,node,id)

n = 0;

% prop to parents
parents = predecessors(G.G,node);
assigned = parents(is_assigned(G,parents,id));
poss = parents(is_possible(G,parents,id));

if isempty(assigned) && numel(poss)==1
    n1 = assign(G,poss,id);
    n = n + n1;
end

% prop to children
children = successors(G.G,node);
assigned = children(is_assigned(G,children,id));
poss = children(is_possible(G,children,id));

if isempty(assigned) && numel(poss)==1
    n2 = assign(G,poss,id);
    n = n + n2;
end

% prop to pairs
%             pairs = union(G.pairs(G.pairs(:,1)==node,2),G.pairs(G.pairs(:,2)==node,1));
%             poss = pairs(is_possible(G,pairs,id));
%
%             if ~isempty(poss)
%                 for i=1:length(poss)
%                     n2 = assign(G,poss,id);
%                     n = n + n2;
%                 end
%             end
end


function nn = propagate_all(G)

report('I','Propagation loops')
nn = 0;
while true
    
    n = 0;
    assigned_nodes = find(any(G.assigned_ids,2));
    for i=1:length(assigned_nodes)
        idix = find(G.assigned_ids(assigned_nodes(i),:));
        for j=1:length(idix)
            nij = propagate(G,assigned_nodes(i),idix(j));
            n = n + nij;
        end
    end
    nn = nn + n;
    report('I',['    ...assigned ',num2str(n),' tracklets']);
    if n==0
        break
    end
end
nnp=nn;

report('I','Biconnected components condition (positive)')
G.pairs = G.pairs(argsort(G.pairs(:,3)),:);
while true
    n=0;
    for i=1:size(G.pairs,1)
        n1 = G.pairs(i,1);
        n2 = G.pairs(i,2);
        a = G.possible_ids(n1,:) & G.possible_ids(n2,:);
        b = G.assigned_ids(n1,:) | G.assigned_ids(n2,:);
        c = find(a & b);
        if isempty(c)
            continue
        end
        % make sure nodes has possible prop route between them
        clear d
        for j=1:length(c)
            ix = false(size(G.trjs));
            ix(n1:n2) = G.possible_ids(n1:n2,c(j));
            ix = find(ix);
            sg = subgraph(G.G,ix);
            d(j) = ~isinf(distances(sg,find(ix==n1),find(ix==n2)));
        end
        c = c(d);
        if isempty(c)
            continue
        end
        n = n + assign(G,n1,c);
        n = n + assign(G,n2,c);
    end
    report('I',['    ...assigned ',num2str(n),' tracklets']);
    nn = nn + n;
    if n==0
        break
    end
end

if nn==nnp
    return
end

report('I','More propagation loops')
while true
    
    n = 0;
    assigned_nodes = find(any(G.assigned_ids,2));
    for i=1:length(assigned_nodes)
        idix = find(G.assigned_ids(assigned_nodes(i),:));
        for j=1:length(idix)
            nij = propagate(G,assigned_nodes(i),idix(j));
            n = n + nij;
        end
    end
    report('I',['    ...assigned ',num2str(n),' tracklets']);
    if n==0
        break
    end
end





end

function n = propagate_neg_all(G)

n = 0;
cands = find(any(G.possible_ids & ~G.assigned_ids,2));

for i=1:length(cands)
    
    node = cands(i);
    
    parents = predecessors(G.G,node);
    children = successors(G.G,node);
    
    
    parents_impossible = all(~G.possible_ids(parents,:));
    children_assigned = any(G.assigned_ids(children,:)) | G.assigned_ids(node,:);
    eliminate(G,node,parents_impossible & ~children_assigned);
    
    children_impossible = all(~G.possible_ids(children,:));
    parents_assigned = any(G.assigned_ids(parents,:)) | G.assigned_ids(node,:);
    
    toelim = (parents_impossible & ~children_assigned) | (children_impossible & ~parents_assigned);
    
    eliminate(G,node,toelim);
    
    n = n + nnz(toelim);
    
end




end

function finalize(G,nodes)
% this method finalize the assigment of the node, i.e.
% eliminate all non assigned ids
G.possible_ids(nodes,:) = G.assigned_ids(nodes,:);
G.finalized(nodes) = true;

end



function OL = cc_overlapping(G,cc)


fi = cellfun(@(x) min(G.node_fi(x)),cc);
ff = cellfun(@(x) max(G.node_ff(x)),cc);

fi = repmat(fi,length(cc),1);
ff = repmat(ff,length(cc),1);

OL = fi<=ff' & ff>=fi';


end


function n = cc_prune(G,cc,id)

ccfi = min(G.node_fi(cc));
ccff = max(G.node_ff(cc));
sg = subgraph(G.G,cc);
n=0;

roots = find(indegree(sg,G.Nodes.Name(cc)) == 0);
roots_trjs = sg.Nodes.trj(roots);
roots_fi = [roots_trjs.fi];
roots = roots(roots_fi<ccfi+100);

% prune all nodes that cannot be reached from root set
d = min(distances(sg,roots,'all'),[],1);
toprune = find(isinf(d));
n = n + length(toprune);
eliminate(G,cc(toprune),id);

% update subgraph
cc(toprune)=[];
sg = rmnode(sg,toprune);

leaves = find(outdegree(sg,G.Nodes.Name(cc)) == 0);
leaves_trjs = sg.Nodes.trj(leaves);
leaves_ff = [leaves_trjs.ff];
leaves = leaves(leaves_ff>ccff-100);

% prune all nodes that cannot be reached from leaves set
d = min(distances(sg,'all',leaves),[],2);
toprune = find(isinf(d));
n = n + length(toprune);
eliminate(G,cc(toprune),id);


end



function olnodes = overlapping_with_cc(G,nodes_to_check,cc)
% this method finds all nodes in nodes_to_check that are
% overlapping with cc

ccfi = min(G.node_fi(cc));
ccff = max(G.node_ff(cc));

ol = G.node_fi(nodes_to_check) <= ccff & G.node_ff(nodes_to_check) >= ccfi;
olnodes = nodes_to_check(ol);
end




