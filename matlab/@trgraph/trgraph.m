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
        
        
        solve(G, skip_pairs_search);
        
        
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
        antxy = export_xy_noprop(G,varargin)
        
        function reset(G)
            % this method reset all id assigments infered from graph
            % propagation
            
            G.assigned_ids = false(G.ntrjs,G.NIDs); % repmat({{}},length(G.trjs),1);
            G.possible_ids = true(G.ntrjs,G.NIDs);  % repmat({G.Trck.usedIDs},length(G.trjs),1);
            G.finalized = false(G.ntrjs,1);
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
        
        
        
        
        function nodes = nodes_from_trjs(G,trjs2look)
            % this method returns the node index of trjs
            nodes = findnode(G.G,{trjs2look.name});
            
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




