classdef trgraph < handle & matlab.mixin.SetGet
    
    properties
        
        expdir
        colony = '';
        aux
        ti trtime
        tf trtime
        node_fi
        node_ff
        node_single
        node_noant
        
        filesuffix = ''
        
    end
    
    properties (Transient)
        
        Trck trhandles
        trjs tracklet
        usedIDs
        NIDs
        pairs
        safe_prop_mode = true
        NumWorkers 
    end
    
    properties (SetAccess = ?tracklet)
        
        G = digraph
        assigned_ids
        possible_ids
        finalized
        E
        isopen
        named_pairs
        pairs_search_depth = 0
        
        datafile
        imagesfile 
        
    end
    
    properties (Dependent)
        
        Nodes
        Edges
        A
        filename
        xyfile
        movlist
        ntrjs
        
    end
    
    
    methods
        
        function G = trgraph(Trck,trjs)
            % initialize a tracklet graph from an existing list of
            % tracklets. If not given, an empty graph is create to be
            % updated during tracking
            
            warning('off','MATLAB:table:RowsAddedExistingVars')
            
            if nargin<2
                trjs = tracklet.empty;
            end
            
            G.Trck = Trck;
            G.usedIDs = Trck.usedIDs;
            G.NIDs = length(Trck.usedIDs);
            G.trjs = trjs;
            G.expdir = Trck.expdir;
            
            if isempty(trjs)
                return
            end
            
            % collect node info
            NodeTable.Name = tocol({trjs.name});
            NodeTable.index = tocol(1:length(trjs));
            NodeTable.trj = tocol(trjs);
            
            % create network from trjs
            A = getConnectMat(trjs,false);
            G.G = digraph(A);
            G.G = digraph(G.G.Edges,struct2table(NodeTable));
            reset(G)
            
            % set 'exist' matrix
            trjs.set_exist;
            G.E = cat(2,trjs(:).exist);
            
        end
        
        
        function newtrjs = new_tracklet(G,blobix)
            % this method creates a new node in the graph and a companion
            % tracklet object, initialized with the blob
            
            if ~G.isopen
                error('Trying to create a new trajectory in a closed TRAJ object');
            end
            
            newtrjs=tracklet.empty;
            for i=1:length(blobix)
                
                newtrj = tracklet(G,blobix(i));
                newtrjs(i)=newtrj;
                G.trjs = [G.trjs;newtrj];
                G.G = addnode(G.G,newtrj.name);
                newnode = findnode(G.G,newtrj.name);
                G.G.Nodes.trj(newnode) = newtrj;
                
                if isfield(G.Trck,'ConnectArraybin') && ~isempty(G.Trck.ConnectArraybin)
                    parents  = G.Trck.prevfrm.antblob.trj(G.Trck.ConnectArraybin(:,blobix(i)));
                    parentnodes = findnode(G.G,{parents.name});
                    G.G = addedge(G.G,parentnodes,newnode*ones(size(parentnodes)));
                end
                
            end
            
        end
        
        function rm_tracklet(G,trj)
            
            if ~isscalar(trj)
                for i=1:length(trj)
                    rm_tracklet(G,trj(i));
                end
            end
            
            if isa(trj,'tracklet')
                trj = find(G.trjs==trj);
            end
            
            G.trjs(trj)=[];
            G.G = G.G.rmnode(trj);
            
        end
        
        function [passed,singles] = get_singles(G,criteria)
            
            if nargin<2
                criteria = {'minarea','maxarea','OneLink'};
            end
            
            if isempty(G.trjs)
                singles=[];
                return
            end
            
                     
            if ~iscell(criteria)
                criteria={criteria};
            end
            
            
            rarea = tocol([G.trjs.nanmeanrarea]);
            nparents = indegree(G.G);
            nchildren = outdegree(G.G);
            
            passed = true(size(G.trjs));
            
            if ismember('rarea',criteria) || ismember('minarea',criteria)
                passed = passed & (rarea > G.Trck.get_param('thrsh_meanareamin'));
            end
            
            if ismember('rarea',criteria) || ismember('maxarea',criteria)
                passed = passed & (rarea < G.Trck.get_param('thrsh_meanareamax'));
            end
            
            if ismember('OneLink',criteria)
                passed = passed & (nchildren<=1) & (nparents<=1);
            end
            
            singles = G.trjs(passed);
            
        end
        
        function close(G)
            % close an object for tracking
            
            if ~G.isopen
                error('Trying to close a closed trgraph object');
            end
            
            G.isopen=false;
            open_trjs = G.trjs([G.trjs.isopen]);
            open_trjs.close(G.Trck);
            report('I',['Closed tracklet graph object']);
            report('I',['... movies ',num2str(G.movlist)]);
            report('I',['... ',num2str(length(G.trjs)),' tracklets']);
            
            % save frame filters
            if G.Trck.get_param('tracking_saveimages') && G.Trck.get_param('tagged')
                passed = G.aux.frame_passed;
                score = G.aux.frame_score;
            
                save([G.Trck.imagedir,'frame_passed_',num2str(G.movlist),G.filesuffix,'.mat'],'-struct','passed','-v7.3');
                save([G.Trck.imagedir,'frame_score_',num2str(G.movlist),G.filesuffix,'.mat'],'-struct','score','-v7.3');
            end
            
            % save single ant tracklets seperately
            trjs = G.trjs(G.trjs.isSingle);
            save([G.Trck.trackletdir,'singles_',num2str(G.movlist),G.filesuffix,'.mat'],'trjs');
        end
        
        
        antxy = export_xy(G,varargin)
        
        function reset(G)
            % this method reset all id assigments infered from graph
            % propagation
            
            G.assigned_ids = false(G.ntrjs,G.NIDs); % repmat({{}},length(G.trjs),1);
            G.possible_ids = true(G.ntrjs,G.NIDs);  % repmat({G.Trck.usedIDs},length(G.trjs),1);
            G.finalized = false(G.ntrjs,1);
        end
        
        
        
        function solve(G,skip_pairs_search)
            
            if nargin<2
                skip_pairs_search = false;
            end
            
            report('I','Some preperations..')
            %G.load_ids;
            G.usedIDs = G.Trck.usedIDs;
            G.NIDs = length(G.usedIDs);
            
            if isempty(G.node_fi)
            G.node_single = G.get_singles;
            G.node_fi = [G.trjs.fi];
            G.node_ff = [G.trjs.ff];
            G.node_noant = ismember({G.trjs.propID},G.Trck.labels.nonant_labels);
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
            
            if G.Trck.get_param('graph_apply_manual_cfg') && exist([G.Trck.paramsdir,'prop.cfg'],'file')
                
                
                cmd = parse_prop_config(G.Trck);
                
                for i=1:size(cmd,1)
                   
                    
                    tracklet = cmd.tracklet{i};
                    
                    if ~ismember(tracklet,G.Nodes.Name)
                        continue
                    end
                    
                    node = find(strcmp(tracklet,G.Nodes.Name));
                    idix = strcmp(cmd.id{i},G.usedIDs);                   
                    
                    switch cmd.command{i}
                        
                        case 'assign'
                            assign(G,node,idix);
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
                    num_of_sources =  0.1 + numel(cc_sources);
                    
                    if num_of_sources>=1
                        max_src_score = max(G.aux.src_score(ismember(G.aux.src_nodes,cc{j})));
                    else
                        max_src_score = 0.1;
                    end
                    
                    cc_score(j) = duration * percent_assigned * num_of_sources * max_src_score;
                    
                end
                
                
                
                
                
                report('I',['......found ',num2str(length(cc)),' cc''s '])
                
          
                
                % filter overlapping cc
                % cc_score = cellfun(@(x) max([G.trjs(x).ff])-min([G.trjs(x).fi]+1),cc);
                no_src_node = cellfun(@(x) isempty(intersect(x,G.aux.src_nodes)),cc);
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
        
        function fix(G,node,id,single)
            % force assign id to node
            G.safe_prop_mode = false;
            
            
            
            
        end
        
        
        function filter_impossible_jumps(G)
            
            G.safe_prop_mode = false;
            
            for i=1:G.NIDs
                
                id = G.usedIDs{i};
                idix = i;
                report('I',['...working on ',id])
                
                
                % get the subraph and connected components of id
                sg = get_id_subgraph(G,id);
                if sg.numnodes==0
                    report('W',['......No assigments for ',id,', skipping'])
                    continue
                end
                
                cc = conncomp(sg,'Type','weak','OutputForm','cell');
                cc = cellfun(@(x) findnode(G.G,x),cc,'UniformOutput',false);
                cc_size = cellfun(@numel,cc);
                report('I',['......found ',num2str(length(cc)),' cc''s '])
                
                % filter adjacant cc with long distance
                dmin = G.Trck.get_param('graph_dmin');
                
                ccfi = cellfun(@(x) min(G.node_fi(x)),cc);
                               
                sortix = argsort(ccfi);
                
                cc = cc(sortix);
                
                ccfi = ccfi(sortix);
                ccff = ccff(sortix);

                nodei = cellfun(@(x) x(argmin(G.node_fi(x))),cc);
                nodef = cellfun(@(x) x(argmax(G.node_ff(x))),cc);
                                
                d  = sqrt(sum((cat(1,G.trjs(nodef(1:end-1)).xyf) - cat(1,G.trjs(nodei(2:end)).xyi)).^2,2));
                dt =  ccfi(2:end)-ccff(1:end-1);
                v = d./dt;
                
                bad = find(v>vmax);
                
                for j=1:length(bad)
                   
                    
                    
                end
                
                
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
                    G.aux.contradictions = G.aux.contradictions + nnz(iscont);
                    G.aux.contradicting_src_nodes = [G.aux.contradicting_src_nodes;find(iscont)];
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
        
        function b = is_assigned(G,nodes,id)
            % this method checks if id is assigned for every node in list
            if ischar(id) || iscell(id)
                id = strcmp(id,G.usedIDs);
            end
            b = G.assigned_ids(nodes,id);
            
        end
        
        function b = is_possible(G,nodes,id)
            % this method checks if id is possible for every node in list
            if ischar(id) || iscell(id)
                id = strcmp(id,G.usedIDs);
            end
            b = G.possible_ids(nodes,id);
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
        
        function ol = overlapping(G,node)
            % this method finds all nodes which are ovelapping in time with
            % node
            if ischar(node)
                node = findnode(G.G,node);
            end
            
            ol = find(G.node_fi<=G.node_ff(node) & G.node_ff>=G.node_fi(node));
            ol(ol==node)=[];
        end
        
        function olnodes = overlapping_with_cc(G,nodes_to_check,cc)
            % this method finds all nodes in nodes_to_check that are
            % overlapping with cc
            
            ccfi = min(G.node_fi(cc));
            ccff = max(G.node_ff(cc));
            
            ol = G.node_fi(nodes_to_check) <= ccff & G.node_ff(nodes_to_check) >= ccfi;
            olnodes = nodes_to_check(ol);
        end
        
        function nodes = nodes_from_trjs(G,trjs2look)
            % this method returns the node index of trjs
            nodes = findnode(G.G,{trjs2look.name});
            
        end
        
        function sg = get_id_subgraph(G,id)
            
            % nodes which have id assigned to them
            nodes = find(is_possible(G,1:numnodes(G.G),id));
            sg = subgraph(G.G,nodes);
            
        end
        
        function d = node_dist(G,nodes1,nodes2)
           % return the ninimu, distance in frames between all nodes in
           % group1 and all nodes in group2
           
           fi1 = G.node_fi(nodes1);
           ff1 = G.node_ff(nodes1);
           fi2 = G.node_fi(nodes2);
           ff2 = G.node_ff(nodes2);
           
           
            for i=1:length(nodes1)
                for j=1:length(nodes2)
                    if i==j
                        d(i,j)=inf;
                        continue
                    end
                    if ff1(i)<fi2(j)
                        d(i,j)=fi2(j)-ff1(i);
                    elseif ff2(j)<fi1(i)
                        d(i,j)=fi1(i)-ff2(j);
                    else
                        d(i,j)=0;
                    end
    
                end
            end
            
            d = min(d(:));
            
            
        end
        
        function pairs = get_bottleneck_pairs(G,skip_pairs_search)
            
            if nargin<2
                skip_pairs_search = false;
            end
            
            maxdepth=G.Trck.get_param('graph_pairs_maxdepth');
            
            if ~isempty(G.named_pairs) && (maxdepth==G.pairs_search_depth || skip_pairs_search)
                G.pairs=[];
                G.pairs(:,1) =  findnode(G.G,G.named_pairs.source);
                G.pairs(:,2) =  findnode(G.G,G.named_pairs.target);
                G.pairs(:,3) =  G.named_pairs.dist;
                G.pairs = G.pairs(~any(G.pairs==0,2),:);
                return
            end
            
            
            report('I','Looking for bottleneck pairs')
            
            if isempty(G.node_fi)
                G.node_fi = [G.trjs.fi];
                G.node_ff = [G.trjs.ff];
            end
            
            din = indegree(G.G);
            dout = outdegree(G.G);
            ignore = tocol(G.node_noant) & din<=1 & dout<=1;
            
            D = distances_low_mem(G.G);
            
            report('I','done distance mat');
            sset = find(din>1 & ~ignore);
                      
            
            for six=1:length(sset)%,G.NumWorkers)
                
                pairs{six} = [];
                
                s = sset(six);
                ss = overlapping(G,s);
                
                des = find(D(s,:)<=maxdepth & D(s,:)>0); %#ok<*PFBNS>
                
                %des = nearest(G.G,s,maxdepth,'Method','unweighted');
                %des = descendents(G.G,s,maxdepth);
                                
                for tix=1:length(des)
                    t=des(tix);
                    tt = overlapping(G,t);
                    sp = double(full(D(s,t)));

                    if sp==1
                        ispair = dout(s)==1 && din(t)==1;
                    else
                        e = any(G.E(G.node_ff(s)+1:G.node_fi(t)-1,:),1);
                        ispair = all(~bitxor(full(D(s,e))==0,full(D(e,t)')==0));
                        noway1 = full(D(ss,t))==0;
                        noway2 = full(D(s,tt))==0;
                        ispair = all(noway1) && all(noway2) && ispair;
                    end
                    

                    if ispair
                        pairs{six}(end+1,:) = [s,t,sp];
                        continue
                    end
                end
            end
            
            pairs = cat(1,pairs{:});
            named_pairs = struct; %#ok<*PROPLC>
            for i = 1:size(pairs,1)
                named_pairs(i).source = G.Nodes.Name{pairs(i,1)};
                named_pairs(i).target = G.Nodes.Name{pairs(i,2)};
                named_pairs(i).dist = pairs(i,3);
            end
            
            pairs = pairs(argsort(pairs(:,3)),:);
            
            G.pairs = pairs;
            
            % save as names
            G.named_pairs = struct2table(named_pairs);
            G.pairs_search_depth = maxdepth;
            
        end
        
        
        function save(G,filename)
            
            
            GS = G.split_by_colony;
            
            if length(GS)>1
                for i=1:length(GS)
                    GS(i).save;
                end
                return
            end
            
            GS = G.split;
            
            if nargin>1 && ~isscalar(GS) && ischar(filename)
                report('E','nonscalar graph and only one filename!')
                return
            end
            
            if nargin>1 && ischar(filename)
                filename = {filename};
            end
            
            if nargin==1
                filename = {GS.filename};
            end
            
            for i=1:length(GS)
                G = GS(i);
                % save tracklets seperately
                trjs = G.trjs;
                [p,f,e] = fileparts(filename{i});
                trjs_file = [p,filesep,f,'_trjs',e];
                save(trjs_file,'trjs','-v7');
                save(filename{i},'G','-v7');
            end
            
        end
        
        function fname = get.filename(G)
            
            p = [G.Trck.graphdir];
            
            if ~isempty(G.colony)
                p=[p,G.Trck.colony_labels{G.colony},filesep];
                mkdirp(p);
            end
            
            f = ['graph_',num2str(min(G.movlist)),'_',num2str(max(G.movlist)),G.filesuffix,'.mat'];
            fname = [p,f];
            
        end
        
        function fname = get.xyfile(G)
            
            p = [G.Trck.trackingdir,'antdata',filesep];
            
            if ~isempty(G.colony)
                p=[p,G.Trck.colony_labels{G.colony},filesep];
                mkdirp(p);
            end
            
            for i=1:length(G.movlist)
                f = ['xy_',num2str(G.movlist(i)),'_',num2str(G.movlist(i)),G.filesuffix,'.mat'];
                fname{i} = [p,f];
            end
            
            if length(fname)==1
                fname=fname{1};
            end
            
        end
        
        function mm = get.movlist(G)
            mm = G.ti.m:G.tf.m;
        end
        
        
        function Nodes = get.Nodes(G)
            Nodes = G.G.Nodes;
        end
        
        function Edges = get.Edges(G)
            Edges = G.G.Edges;
        end
        
        function set.Trck(G,Trck)
            
            for i=1:length(G)
                G(i).Trck = Trck;
                set(G(i).trjs,'Trck',Trck);
            end
        end
        
        function A = get.A(G)
            A = adjacency(G.G);
        end
        
        function n = get.ntrjs(G)
            n = length(G.trjs);
        end
        
        function mat = get.datafile(G)
            
            if isempty(G.datafile)
                f = [G.Trck.trackletdir,'trdata_',num2str(max(G.movlist)),G.filesuffix,'.mat'];
                G.datafile = matfile(f,'Writable',true);
            end
            mat = G.datafile;
            
        end
        
        function mat = get.imagesfile(G)
            
            if isempty(G.imagesfile)
                f = [G.Trck.imagedir,'images_',num2str(max(G.movlist)),G.filesuffix,'.mat'];
                G.imagesfile = matfile(f,'Writable',true);
            end
            mat = G.imagesfile;
            
        end
        
        function clear_data(G)
            
            for i=1:length(G.trjs)
                G.trjs(i).data_ = [];
            end
            
        end
        
        function load_ids(G)
            
            if ~isempty(G.trjs)
                G.trjs.load_ids;
            end
            
        end
        
        function set_data(G)
            
            for i=1:length(G.movlist)
                
                m = G.movlist(i);
                
                trjs = G.trjs([G.trjs.m]==m);
                
                if isempty(trjs)
                    continue
                end
                
                trdata = load([G.Trck.trackletdir,'trdata_',num2str(m),G.filesuffix,'.mat']);
                
                for j=1:length(trjs)
                    trj=trjs(j);
                    A = trdata.(trj.name);
                    if size(A,2)==17
                        A = mat2cell(A,ones(1,size(A,1)),[1,2,1,1,1,1,4,1,1,1,1,1,1]);
                    elseif size(A,2)==16
                        A = mat2cell(A,ones(1,size(A,1)),[1,2,1,1,1,1,4,1,1,1,1,1]);
                    end
                    A = cell2table(A);
                    A.Properties.VariableNames = trj.datai.Properties.VariableNames;
                    A.ORIENT = angle(A.ORIENT);
                    A.BBOX = int32(A.BBOX);
                    A.AREA = int32(A.AREA);
                    A.MAXZ = uint8(A.MAXZ);
                    trj.data_ = A;
                end
            end
            
        end
        
        
        function GS = split(G)
            
            
            if ~isscalar(G)
                report('E','can only split scalar graphs')
                return
            end
            
            if length(G.movlist)<=1
                GS = G;
                return
            end
            
            
            Trck = G.Trck;
            
            for i=1:length(G.movlist)
                m = G.movlist(i);
                GS(i) = trgraph(Trck);
                GS(i).expdir = Trck.expdir;
                GS(i).usedIDs = G.usedIDs;
                GS(i).NIDs = G.NIDs;
                GS(i).colony = G.colony;
                GS(i).ti = trtime(Trck,Trck.er.movies_info(m).fi);
                GS(i).tf = trtime(Trck,Trck.er.movies_info(m).ff);
                ix = [G.trjs.m]==m;
                GS(i).trjs = G.trjs(ix);
                GS(i).G = subgraph(G.G,ix);
                GS(i).E = G.E(:,ix);
                if ~isempty(G.assigned_ids)
                GS(i).assigned_ids = G.assigned_ids(ix,:);
                GS(i).possible_ids = G.possible_ids(ix,:);
                GS(i).finalized = G.finalized(ix,:);
                end
                GS(i).isopen = false;
                GS(i).named_pairs = G.named_pairs;
                GS(i).pairs_search_depth = G.pairs_search_depth;
            end
            
            
        end
        
        function GS = split_by_colony(G)
            
            
            if ~isscalar(G)
                report('E','can only split scalar graphs')
                return
            end
            
            
            if ~G.Trck.get_param('geometry_multi_colony')
                GS = G;
                return
            end
                        
            clist = [G.trjs.colony];
            cs = sort(unique(clist));
            if length(cs)==1
                GS=G;
                GS.colony = clist(1);
                return
            end
            
            Trck = G.Trck;
            
            for i=1:length(cs)
                c = cs(i);
                GS(i) = trgraph(Trck);
                GS(i).expdir = Trck.expdir;
                GS(i).usedIDs = G.usedIDs;
                GS(i).NIDs = G.NIDs;
                GS(i).ti = G.ti;
                GS(i).tf = G.tf;
                GS(i).colony = c;
                ix = clist==c;
                GS(i).trjs = G.trjs(ix);
                GS(i).G = subgraph(G.G,ix);
                GS(i).isopen = false;
                GS(i).named_pairs = G.named_pairs;
            end
            
            
        end
        
        function XY = loadxy(G)
            
           fnames = G.xyfile;
           
           if ischar(fnames)
               XY = load(fnames);
               return
           end
           
           for i=1:length(fnames)
               xy(i) = load(fnames{i});
           end
           
           XY = struct;
           
           for i=1:G.NIDs
               XY(1).(G.usedIDs{i}) = cat(1,xy.(G.usedIDs{i}));
           end
            
            
        end
        
        h = plot(G,ti,tf);
        
    end
    
    
    methods (Static)
        
        function G = loadobj(G)
            
            set(G.trjs,'G',G);
            
            
        end
        
        
        function GS = load(Trck,movlist,colony,part)
            
            if nargin<4
                part=[];
            end
            
            if nargin<3
                colony = [];
            end
            
            if ~isempty(colony) && isnumeric(colony)
                colony = Trck.colony_labels{colony};
            end
            
            if isempty(colony)
                gdir = Trck.graphdir;   
            else
                gdir = [Trck.graphdir,colony,filesep];
            end
            
            for i=1:length(movlist)
                m = movlist(i);
                
                % is the graph splitted?
                splitted = exist([gdir,'graph_',num2str(m),'_',num2str(m),'_p1.mat'],'file');
                
                if splitted && length(movlist)>1
                    error('Cannot load splitted graph together with other graphs')
                end
                
                if splitted
                
                    GS = trgraph.load_splitted(Trck,m,colony,part);
                    return
    
                end
                
                fname = [gdir,'graph_',num2str(m),'_',num2str(m),'.mat'];
                report('I',['Loading trgraph from ',fname(length(Trck.expdir)+1:end)])
                load(fname,'G');
                G.Trck = Trck;
                
                [p,f,e] = fileparts(fname);
                trjs_file = [p,filesep,f,'_trjs',e];

                if isempty(G.trjs) && exist(trjs_file,'file')
                    load(trjs_file,'trjs');
                    G.trjs=trjs;
                elseif isempty(G.trjs)
                    report('W','No tracklets in trgraph')
                end
                set(G.trjs,'Trck',G.Trck);
                set(G.trjs,'G',G);
                G.G.Nodes.trj = tocol(G.trjs);
                
                if isempty(G.E)    
                    G.trjs.set_exist;
                    G.E = cat(2,G.trjs(:).exist);
                end
                
                
                % load autoid file if exist
                G.load_ids;
                G.trjs.set_index;
                GS(i) = G;
            end
            
            report('I',['Finished loading trgraph with ',num2str(sum([GS.ntrjs])),' tracklets'])
            
        end
        
        function GS = load_splitted(Trck,m,colony,part)
                        
            if isempty(colony)
                gdir = Trck.graphdir;   
            else
                gdir = [Trck.graphdir,colony,filesep];
            end
            
            % find all parts
            a = dir([gdir,'graph_',num2str(m),'_',num2str(m),'_p*.mat']);
            a = {a.name};
            a = a(~contains(a,'trjs'));
            f1 = @(x) strsplit(x(1:end-4),'_p');
            f2 = @(x) str2double(x{2});
            p = cellfun(@(x) f2(f1(x)), a);
            a = a(argsort(p));
            p = sort(p);
            
            if ~isempty(part)
                p = part;
                a = {['graph_',num2str(m),'_',num2str(m),'_p',num2str(part),'.mat']};
            end
               
            
            % load
            for i=1:length(p)
                fname = [gdir,a{i}];
                
                load(fname,'G');
                G.Trck = Trck;
                
                [p,f,e] = fileparts(fname);
                trjs_file = [p,filesep,f,'_trjs',e];

                if isempty(G.trjs) && exist(trjs_file,'file')
                    load(trjs_file,'trjs');
                    G.trjs=trjs;
                elseif isempty(G.trjs)
                    report('W','No tracklets in trgraph')
                end
                set(G.trjs,'Trck',G.Trck);
                
                if isempty(G.E)    
                    G.trjs.set_exist;
                    G.E = cat(2,G.trjs(:).exist);
                end
                
                % load autoid file if exist
                G.load_ids;
                G.trjs.set_index;
                GS(i) = G;
                
            end
            
            
        end
        
        function G = merge(GS)
            % merge several trgraph object into one. return the merged
            % graph
            
            
            Trck = GS(1).Trck;
            for i=1:length(GS)
                if GS(i).Trck ~=Trck
                    report('E','All graphs must have the same Trck')
                end
            end
            
            G = trgraph(Trck);
            G.expdir = Trck.expdir;
            G.ti = min([GS.ti]);
            G.tf = max([GS.tf]);
            G.trjs = cat(1,GS.trjs);
            G.colony = sort(unique([GS.colony]));
            A = blkdiag(GS.A);
            %G.OL = blkdiag(GS.OL);
            G.G = digraph(A);
            G.E = cat(2,GS.E);
            G.G.Nodes = cat(1,GS.Nodes);
            G.assigned_ids = cat(1,GS.assigned_ids);
            G.possible_ids = cat(1,GS.possible_ids);
            G.finalized = cat(1,GS.finalized);
            G.isopen = false;
            G.named_pairs = cat(1,GS.named_pairs);
            G.named_pairs = unique(G.named_pairs,'rows');
            G.pairs_search_depth = min([GS.pairs_search_depth]);
            set(G.trjs,'G',G);
            set(G.trjs,'Trck',Trck);
            G.trjs.set_index;
            
            % add cross movie edges
            linkfile = [Trck.graphdir,'cross_movie_links.mat'];
            if exist(linkfile,'file')
                load(linkfile);
                % filter links within this graph
                cross_movie_links = cross_movie_links(ismember({cross_movie_links.parent},G.Nodes.Name) & ismember({cross_movie_links.child},G.Nodes.Name));
                % add edges to the graph
                for k=1:length(cross_movie_links)
                    G.G = addedge(G.G,cross_movie_links(k).parent,cross_movie_links(k).child,1);
                    %link(G.trjs.withName(cross_movie_links(k).parent),G.trjs.withName(cross_movie_links(k).child));
                end
            end
        end
        
        
        
    end
    
end




