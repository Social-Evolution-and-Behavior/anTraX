function OUT = infer_nants_untagged(G)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

nants = nan(size(G.trjs));
touching = cat(1,G.trjs.touching_open_boundry);

nodes_single = G.trjs.isSingle;
nants(nodes_single) = 1;

% look for orphan tracklets that are less than an ant
noant = [G.trjs.nparents]==0 & [G.trjs.nchildren]==0 & [G.trjs.nanmeanrarea]<G.Trck.get_param('thrsh_meanareamin');
nants(noant) = 0;

nodes_single = [G.trjs.nparents]<=1 & [G.trjs.nchildren]<=1 & [G.trjs.nanmeanrarea]<G.Trck.get_param('thrsh_meanareamin') & torow(isnan(nants));
nants(nodes_single) = 1;

while true
    
    unassigned = find(isnan(nants) & ~touching);
    nnodes_assigned = sum(~isnan(nants));
    
    for i=1:length(unassigned)
        
        node = unassigned(i);
        trj = G.trjs(node);
                
        nc = nan;
        np = nan;
        
        
        parents = trj.parents_index;
        siblings = trj.siblings_index;
        children = trj.children_index;
        coparents = trj.coparents_index;
        
        if ~isempty(parents) && isempty(siblings) && all(~isnan(nants(parents)))
            np = sum(nants(parents));
        elseif ~isempty(parents) && all(~isnan(nants(parents))) && all(~isnan(nants(siblings))) && seteq(parents,cat(1,trj.siblings.parents_index))
            np = sum(nants(parents)) - sum(nants(siblings));
        end

        if ~isempty(children) && isempty(coparents) && all(~isnan(nants(children)))
            nc = sum(nants(children));
        elseif ~isempty(children) && all(~isnan(nants(children))) && all(~isnan(nants(coparents))) && seteq(children,cat(1,trj.coparents.children_index))
            nc = sum(nants(children)) - sum(nants(coparents));
        end
        
        if isnan(nc) && isnan(np)
            continue
        elseif isnan(nc) 
            nants(node) = np;
        elseif isnan(np)
            nants(node) = nc;
        elseif nc==np
            nants(node) = nc;
        elseif ~isnan(np) && ~isnan(nc)
            nants(node) = np;
 
        end
        
    end
    
    nnodes_assigned_new = sum(~isnan(nants));
    if nnodes_assigned_new > nnodes_assigned
        disp(['assigned ',num2str(nnodes_assigned_new-nnodes_assigned),' nodes'])
    else
        break
    end
end

% diamonds
nants1 = nants;
unassigned = find(isnan(nants));
cnt=0;
for i=1:length(unassigned)
    
    node = unassigned(i);
    trj = G.trjs(node);
    
    siblings = [trj.siblings;trj];
    coparents = [trj.coparents;trj];
    
    if ~seteq(siblings,coparents), continue, end
    
    all_parents = cat(1,siblings.parents);
    all_children = cat(1,siblings.children);
    
    cand = seteq(cat(1,all_parents.children_index), [node;trj.siblings_index])...
        && seteq(cat(1,all_children.parents_index), [node;trj.siblings_index]);
    
    if ~cand, continue, end
    
    nc = sum(nants1([all_children.index]));
    np = sum(nants1([all_parents.index]));
    nsib = length(siblings);
    
    if ~isnan(np) && ~isnan(nc) && nc==np
        
            nants(node) = np/nsib;
            cnt=cnt+1;

    elseif ~isnan(np) && isnan(nc)
        
        nants(node) = np/nsib;
        cnt=cnt+1;
        
    elseif isnan(np) && ~isnan(nc)
        
        nants(node) = nc/nsib;
        cnt=cnt+1;
        
    else
        
        nants(node) = np/nsib;
        cnt=cnt+1;
        
    end
    
    
    
end

disp(['assigned ',num2str(cnt),' diamonds'])


exits = zeros(size(nants));
entrances = zeros(size(nants));

cands = find(touching);

for i=1:length(cands)
    
    node = cands(i);
    trj = G.trjs(node);
    
    if trj.nparents==0 && trj.nchildren==0
        continue 
    
    % if no parents and children assigned
    elseif trj.nparents==0 && all(~isnan(nants(trj.children_index)))...
            && all(~isnan(nants(trj.coparents_index)))...
            && seteq(trj.children_index,cat(1,trj.coparents.children_index,trj.children_index))
            
        nants(node)= max([1,sum(nants(trj.children_index)) - sum(nants(trj.coparents_index))]);
        exits(node) = nants(node);
        
    % if no parents and children not assigned
    elseif trj.nparents==0 
        
        at_least = max([1,sum(nants(cat(1,trj.coparents.children_index)),'omitnan') - sum(nants(trj.coparents_index),'omitnan')]);
        
        nants(node) = at_least;
        exits(node) = at_least;
        
    % if no children and parents assigned
    elseif trj.nchildren==0 && all(~isnan(nants(trj.parents_index)))...  
            && all(~isnan(nants(trj.siblings_index)))...
            && seteq(trj.parents_index,cat(1,trj.siblings.parents_index,trj.parents_index))
        
        nants(node) = max([1,sum(nants(trj.parents_index)) - sum(nants(trj.siblings_index))]);
        entrances(node) = nants(node);
        
    % if no children and parents not assigned     
    elseif trj.nchildren==0
    
        at_least = max([1,sum(nants(cat(1,trj.siblings.parents_index)),'omitnan') - sum(nants(trj.siblings_index),'omitnan')]);
        
        nants(node) = at_least;
        entrances(node) = at_least;
    
    % if parents AND children all assigned
    elseif all(~isnan(nants(trj.parents_index)))...
            && all(~isnan(nants(trj.children_index)))...
            && seteq(trj.children_index,cat(1,trj.coparents.children_index,trj.children_index))...
            && seteq(trj.parents_index,cat(1,trj.siblings.parents_index,trj.parents_index))
        
        np = max([1,sum(nants(trj.parents_index)) - sum(nants(trj.siblings_index))]);
        nc = max([1,sum(nants(trj.children_index)) - sum(nants(trj.coparents_index))]);
        
        nants(node) = np;
        if np>nc
            entrances(node) = np-nc;
        elseif nc>np
            exits(node) = nc-np;
        end
    
    else
        
        np_at_least = max([1,sum(nants(cat(1,trj.siblings.parents_index)),'omitnan') - sum(nants(trj.siblings_index),'omitnan')]);
        nc_at_least = max([1,sum(nants(cat(1,trj.coparents.children_index)),'omitnan') - sum(nants(trj.coparents_index),'omitnan')]);
        
        nants(node) = np_at_least;
        if np_at_least>nc_at_least
            entrances(node) = np_at_least-nc_at_least;
        elseif nc_at_least>np_at_least
            exits(node) = nc_at_least-np_at_least;
        end
        
    end

end

set(G.trjs,{'nants'},mat2cell(nants,ones(1,length(nants))));

exit_times = [G.trjs(exits>0).fi] - G.ti.f + 1;
entrance_times = [G.trjs(entrances>0).fi] - G.ti.f + 1;

if nargout>1
OUT.nants = nants;
OUT.exits = exits;
OUT.entrances = entrances;
OUT.exit_times = exit_times;
OUT.entrance_times = entrance_times;
end

G.save

if G.Trck.get_param('geometry_open_boundry')
    mkdirp([G.Trck.trackingdir,'antdata']);
    save([G.Trck.trackingdir,'antdata/exits_entrances_',num2str(G.movlist(1)),'.mat'],'exit_times','entrance_times','-v7.3');
end

