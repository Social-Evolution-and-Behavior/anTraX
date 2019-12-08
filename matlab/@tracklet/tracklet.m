classdef  tracklet < handle  &  matlab.mixin.SetGet & matlab.mixin.Copyable & matlab.mixin.CustomDisplay
    
    %%
    properties 
        
        
        %%% information properties
        
        name char           % tracklet name (unique in experiment)
        expname char        % expname
        index = nan         % tracklet index in movie
        len = 0             % tracklet length
        ti trtime           % start frame info
        tf trtime           % end frame info
        colony              % colony index
        colony_label        % colony label
        
        ID struct           % struct to hold ID info
        exist
        comments = {}
        nants = NaN
        
    end
    
    
    properties  (Transient)
        
        %%% data properties (not saved with object)
        
        data_
        images_
        
        dataflds
        
        datachanged = false
        imageschanged = false
 
    end
    
    properties (Transient)
        
        %%% ref to other objects
        
        Trck trhandles      % pointer to trhandles object
        G trgraph           % pointer to containing trgraph
        
        %%% properties to be used during tracking
        
        blobID
        isopen logical
        tmp struct
        
    end
    
    properties 
        
        %%% useful stats to keep with tracklet without loading full data
        
        datai
        dataf
        nanmeanrarea
        touching_open_boundry = false
        
    end
    
    
    properties (Dependent)
        
        dscale              % the spatial scale factor (pix/m)
        
        %%% pointers to data files
        
        datafile 
        imagesfile 
        
        %%%% graph neighbours aliases
        
        parents tracklet    % pointer to parent tracklets (through G)
        children tracklet   % pointer to children tracklets (through G)
        parents_index
        children_index
        siblings
        siblings_index
        coparents
        coparents_index
        
        %%% useful info aliases
        m
        tt
        fi
        ff
        
        nparents
        nchildren
        
        
        %%% aliases for data_ fields
        
        AREA
        CENTROID
        MAJAX
        ECCENT
        ORIENT
        MAXZ
        BBOX
        ONBOUNDRY
        dt
        
        %%% aliases for getting on-the-fly computed data features
        
        rarea
        xy
        x
        y
        v
        vnorm
        vang
        acc
        vx
        vy
        CX
        CY
                
        %%% aliases for summary stats
        
        xi
        yi
        xyi
        xf
        yf
        xyf
        Ci
        Cf
        
        
        %%% ID related aliases
        
        manualID
        autoID
        propID
        propScore
        finalID
        
        
    end
    
    
    methods
        
        
        % tracklet initialization function
        function trj = tracklet(G,blobix)
            
            if nargin<2
                % used to initialize object arrays
                return
            end
            
            Trck = G.Trck;
            trj.Trck = Trck;
            trj.G = G;
            
            % accept data when created
            trj.isopen = true;
            
            % set blobID  to blobidx
            trj.blobID = Trck.currfrm.antblob.blobID(blobix);
            
            % the first frame is the current frame
            trj.ti = Trck.currfrm.t;
            
            % initilaize name to temporary value using blobID
            trj.name = ['trj_id' num2str(trj.blobID)];
            
            % store the experiment name
            trj.expname = Trck.expname;
            
            % get the scale
            % trj.dscale = Trck.get_param('geometry_rscale');
            
            % maximum number of frames remaining in the current movie gives
            % the maximum length of the data for the following fields
            K = Trck.frames2go;
            
            if  Trck.get_param('tracking_max_tracklet_length')>0
                K = min(K,Trck.get_param('tracking_max_tracklet_length'));
            end
            
            % initialize these fields to Nans
            trj.data_ = init_tracklet_data(K);
            sqsz = Trck.get_param('sqsz');
            if Trck.get_param('tracking_saveimages')
                trj.images_ = zeros([sqsz,sqsz,Trck.er.nchannels,min([K,50])],'uint8');
            end
            % add the first blob
            trj.add_blob(Trck,blobix);
            
            
        end
        
        add_examples(trj,varargin)
        add_manual_id(trj,varargin);
        
        function add_blob(trjs,Trck,blobixs)
            % During tracking, will add blobix in the current frame to
            % trajectory
            
            if ~all([trjs.isopen])
                error('Trying to add blob to a closed trajectory!');
            end
            
            if length(trjs)~=length(blobixs)
                error('Input size mismatch between blobs and trajectories!');
            end
            
            % for each tracklet in trjs
            for i=1:length(trjs)
                
                % get the corresponding index
                blobix = blobixs(i);                
                trj = trjs(i);
                
                % get the new length
                ix = trj.len+1;
                
                % update the Trck structure with the updated tracklet
                Trck.currfrm.antblob.trj(blobix,1)=trj;
                
                % increment the length of this trajectory
                trj.len = trj.len+1;
                
                % assign data
                trj.data_(ix,:) =  Trck.currfrm.antblob.DATA(blobix,trj.data_.Properties.VariableNames);
                trj.data_.dt(ix) = Trck.currfrm.dat.dt;
                
                if Trck.get_param('tracking_saveimages')
                    trj.images_(:,:,:,ix) = Trck.currfrm.antblob.images(:,:,:,blobix);
                end
                
            end
            
            
        end
               
        
        function ConnectMat = getConnectMat(trjs,check_membership)
            % 02/23/17
            % this function create a square sparse logical array of size the number of
            % elements in the 'tracklet' thesetrjs. Also returns the trajectories
            % ordered by starting frame
            
            Ntrjs = numel(trjs);
            
            if nargin<2
                check_membership=true;
            end
            
            report('I',['Creating a sparse ''connection matrix'' for ' num2str(Ntrjs) ' tracklets']);
            ConnectMat = sparse(Ntrjs,Ntrjs);
            set_index(trjs);
            for i=1:Ntrjs
                if rem(i,10000)==0
                    report('I',['Finished ',num2str(i),'/',num2str(Ntrjs)]);
                end
                ch = trjs(i).children_ref;
                p = trjs(i).parents_ref;
                if check_membership
                    ch = intersect(ch,trjs);
                    p = intersect(p,trjs);
                end
                ConnectMat(i,[ch.index]) = true;
                ConnectMat([p.index],i) = true;
            end
            
            ConnectMat = logical(ConnectMat);
            report('G','Done!')
            
            
        end
        
        
        
        function [out_trjs,indexes] = withName(in_trjs,Names,varargin)
            % find the tracklet with name 'Names'. Names can be just a part of
            % the name.
            p = inputParser();
            
            addRequired(p,'in_trjs',@(x) isa(x,'tracklet'));
            addRequired(p,'Names',@(x) ischar(x) || iscellstr(x));
            addParameter(p,'fullName',false,@islogical);
            
            parse(p,in_trjs,Names,varargin{:});

            if p.Results.fullName
                indexes = find(ismember({in_trjs.name},Names));
            else
                indexes = find(contains({in_trjs.name},Names));
            end
            
            % create the tracklet vector
            out_trjs = in_trjs(indexes);
            
            
        end
        
        function [passed,trjs] = withManual(trjs,id)
            
            
            mids={trjs.manualID};
            if nargin>1 && iscell(id)
                passed = ismember(mids,id);
            elseif nargin>1
                passed = strcmp(mids,id);
            else
                passed = ~cellfun(@isempty,mids);
            end
                
            if nargout>1
                trjs = trjs(passed);
            end
            
        end
        
        function [passed,trjs] = withAuto(trjs,id)
            
            aids = {trjs.autoID};
            if nargin>1 && iscell(id)
                passed = ismember(aids,id);
            elseif nargin>1
                passed = strcmp(aids,id);
            else
                passed = ismember(aids,trjs(1).Trck.usedIDs);
            end
            
            if nargout>1
                trjs = trjs(passed);
            end
                         
        end
       
        
        function [passed,trjs] = isSingle(trjs,varargin)
            % filter for single ants
            p = inputParser();
            % apply to a tracklet array
            addRequired(p,'trjs',@(x) isa(x,'tracklet'));
            % criteria for single ants
            % rarea :       m^2
            % OneLink:      can only have one parent and one child
            addOptional(p,'criteria',{'minarea','maxarea','OneLink'},@(x) all(ismember(x,{'rarea','OneLink','minarea','maxarea'})));
            
            parse(p,trjs,varargin{:})
                        
            if isempty(trjs)
                passed=[];
                return
            end
            
            if isempty(trjs(1).G)
                report('E','no graph is defined in tracklets!')
            end
            
            Trck = trjs(1).Trck; %#ok<*PROPLC>
            
            criteria = p.Results.criteria;
            if ~iscell(criteria)
                criteria={criteria};
            end
            
            
            rarea = tocol([trjs.nanmeanrarea]);
            nparents = tocol([trjs.nparents]);
            nchildren = tocol([trjs.nchildren]);
            
            passed = true(size(trjs));
            
            if ismember('rarea',criteria) || ismember('minarea',criteria)
                passed = passed & (rarea > Trck.get_param('thrsh_meanareamin'));
            end
            
            if ismember('rarea',criteria) || ismember('maxarea',criteria)
                passed = passed & (rarea < Trck.get_param('thrsh_meanareamax'));
            end
            
            if ismember('OneLink',criteria)
                passed = passed & (nchildren<=1) & (nparents<=1);
            end
            
            if nargout>1
                trjs = trjs(passed);
            end
            
        end
        

        function close(trjs,Trck)
            % Close trajectory for trackign, and set meta data. Will also
            % calculate measures and fix orientation data.
            
            % loop that closes all the tracklet in trj
            if ~isempty(trjs)
                for i=1:length(trjs)
                    trjs(i).close_single_trj;
                end
            end
            
        end
        
        function clearID(trjs)
            for i=1:length(trjs)
                trjs(i).ID = struct;
            end
        end
        
        
        function set_index(trjs)
            Ntrjs = numel(trjs);
            set(trjs,{'index'},mat2cell((1:Ntrjs)',ones(1,Ntrjs)));
        end
        
        function set_cotrjs(trjs)
            
            EX = cat(2,trjs.exist);
            for j=1:length(trjs)
                trj=trjs(j);
                a= inTime(trjs,trj.ti:trj.tf,'existMat',EX);
                trj.cotrjs = a(a~=trj);
            end
            
        end

        
        function set_exist(trjs,Trck)
            % set the exist sparse matrx property
            
            if isempty(trjs)
                return
            end
            
            if nargin==1 || isempty(Trck)
                if length(trjs)>1 && ~all([trjs.Trck]==trjs(1).Trck)
                    report('E','All trajectories must have the same Trck field, or give it as a second argument')
                    report('E','Abborting')
                    return
                end
                Trck = trjs(1).Trck;
            end
            
            for i=1:length(trjs)
                trjs(i).exist = sparse(Trck.er.totalframenum,1);
                trjs(i).exist(trjs(i).ti.absframe:trjs(i).tf.absframe) = true;
            end
            
        end
        
        
        function a=isfield(trj,fld)
            % Support the struct syntax 'isfield'
            a = isprop(trj,fld);
        end
        
        
        
        
        function [out_trjs,indexes] = inTime(trjs,t,varargin)
            % this function returns a tracklet in 'trjs' that exist in any of
            % the times in 't'
            p = inputParser();
            addRequired(p,'trjs',@(x) isa(x,'tracklet'));
            addRequired(p,'t',@(x) isa(x,'trtime') | isnumeric(x));
            addOptional(p,'existMat',cat(2,trjs(:).exist),@(x) isempty(x) | size(x,2)==numel(trjs));
            parse(p,trjs,t,varargin{:});
            
            
            if isa(t,'trtime')
                t = [t(:).absframe];
            end
            
            t = t(t<size(p.Results.existMat,1));
            
            indexes = any(p.Results.existMat(t,:),1);
            
            out_trjs = trjs(indexes);
            
        end
        
        
        function indx = time2indx(trj,tt)
            % utility function to return the index of time tt in the
            % trajectory
            
            if isa(tt,'trtime')
                f = [tt.f];
            else
                f = tt;
            end
            tis = [trj.ti];
            indx = f - [tis.f] + 1;
            
            % get rid of indexes that cannot exist
            indx(indx<=0) = [];
            indx(indx>trj.len) = [];
            
        end
        
        function tt = indx2time(trj,indx)
            % utility function to return the index of time tt in the
            % trajectory
            
            if indx>trj.len
                error(['position# ' num2str(indx) ' but this tracklet only has ' num2str(trj.len) ' frames']);
            elseif indx<0
                error(['the position in the tracklet must be a positive integer smaller than ' num2str(trj.len)]);
            else
                tt = trj.ti+indx-1;
            end
        end
        
        function mi = max_intensity(trj,tt)
            
            if ~isscalar(trj)
                error('only scalar trj')
            end
            
            if nargin<2
                tt = trj.ti:trj.tf;
            end
            
            if ~isempty(trj.MAXINT)
                mi = trj.MAXINT(trj.time2indx(tt));
            else
                for i=1:length(tt)
                    im = rgb2gray(get_image(trj,tt(i),[],'masked',false));
                    mi(i) = 1-min(im(im~=0));
                end
            end
        end
        
        function msk = get_frame_mask(trj,tt)
            
            if nargin<2
                tt = trj.ti:trj.tf;
            end
            
            for i=1:length(tt)
                t=tt(i);
                trj.Trck.read_frame(t);
                blobdetector(trj.Trck);
                C = trj.get('CENTROID',t);
                ab = trj.Trck.currfrm.antblob;
                d = sum((ab.CENTROID - repmat(C,ab.Nblob,1)).^2,2);
                label = argmin(d);
                msk(:,:,i) = ab.LABEL==label;
            end
            
            
            
        end
        
        
        function im = get_image(trj,tt)
            
            % return a cropped and rotated image of the ant in time tt.
            % Trck is not required if defined in trajectory
                        
            if ~isscalar(trj)
                error('get_image support only scalar tracklet')
            end
                        
            if nargin<2 || isempty(tt)
                tt = trj.ti;
            end
            
            if ischar(tt) && strcmp(tt,'all')
                tt = trj.ti:trj.tf;
            end
            
            if isnumeric(tt)
                tt = trtime(trj.Trck,tt);
            end
            
            if ~isempty(trj.exist) && ~all(trj.exist([tt.absframe]))
                error('tracklet does not exist in requested frame')
            end
            
            ix = trj.time2indx(tt);
            
            % if trj contains images
            if ~isempty(trj.images_)
                im = trj.images_(:,:,:,ix);
                return
            end
            
            % if images in mat file
            w = whos(trj.imagesfile);
            if ismember(trj.name,{w.name})
                im = trj.imagefile.(trj.name)(:,:,:,ix);
                return
            end
            
            % else
            im = get_image_from_vid(trj,tt);
            
        end

        function image(trj,tt,Trck,type,newfig)
            
            % display a cropped and rotated image of the ant in time tt.
            % Trck is not required if defined in trajectory. the image is
            % flipped to display "head up"
            
            if nargin<5
                newfig=true;
            end
            
            if nargin<4 || isempty(type)
                type='corrected';
            end
            
            if nargin<3 || isempty(Trck)
                Trck = trj.Trck;
            end
            
            if nargin<2 || isempty(tt)
                tt = trj.ti;
            end
            
            if trj.isSingle && trj.len<100
                saveim=true;
            else
                saveim=false;
            end
            
            im = get_image(trj,tt);
            flp = isempty(trj.ID) || ~isfield(trj.ID,'flipped') || isempty(trj.ID.flipped) || isnan(trj.ID.flipped) || ~(trj.ID.flipped);
            if flp
                im = flipm(im,[1,2]);
            end
            if newfig
                h=figure;
            else
                h=gcf;
            end
            if length(tt)==1 || trj.len==1
                image(im);
            else
                montage(im);
            end
            set(h,'Name',['tracklet #',num2str(trj.index),': ',trj.name],'NumberTitle','off');
            
        end
        

        function addPi(trjs)
            
            for i=1:length(trjs)
                trjs(i).ORIENT = trjs(i).ORIENT+pi;
            end
            
        end
        
        function link(parent,child)
            parent.children = unique([parent.children;child]);
            child.parents = unique([child.parents;parent]);
            
        end
        
        function new = split(trj,tsplit)
            
            if length(trj)~=1
                error('split only one trj at a time')
            end
            
            if isempty(trj.inTime(tsplit)) || tsplit==trj.ti
                error('wrong tsplit')
            end
            
            ixsplit = trj.time2indx(tsplit);
            
            new = tracklet;
            new.name = [trj.name,'_split2'];
            new.Trck = trj.Trck;
            new.colony = trj.colony;
            new.expname = trj.expname;
            new.dscale = trj.dscale;
            new.data_fields = trj.data_fields;
            new.parents_ref = trj;
            new.children_ref = trj.children_ref;
            trj.children_ref = new;
            trj.rename([trj.name,'_split1']);
            new.ti = tsplit;
            new.tf = trj.tf;
            trj.tf = tsplit-1;
            new.len = new.ff-new.fi+1;
            trj.len = trj.len - new.len;
            new.isopen = false;
            trj.imagedir = '';
            
            for i=1:length(trj.data_fields)
                fld = trj.data_fields{i};
                new.(fld) = trj.(fld)(ixsplit:end,:);
                trj.(fld) = trj.(fld)(1:ixsplit-1,:);
            end
            new.dt = trj.dt(ixsplit:end,:);
            trj.dt = trj.dt(1:ixsplit-1,:);
            
            new.set_velocity();
            new.set_measures();
            trj.set_velocity();
            trj.set_measures();
            
            new.set_exist;
            trj.set_exist;
            
            
        end
     
        function load_ids(trjs)
            
            Trck = trjs(1).Trck;
            
            trjnames = {trjs.name};
            
            movlist = sort(unique([trjs.m]));
            
            % auto ids
            for i=1:length(movlist)
                
                f = [Trck.labelsdir,'autoids_',num2str(movlist(i)),'.csv'];
                if ~exist(f,'file')
                    continue
                end
                T = readtable(f);
                
                ix = ismember(T.tracklet,trjnames);
                T = T(ix,:);
                
                if isempty(T)
                    return
                end
                
                ix=cellfun(@(x) find(strcmp(x,trjnames)),T.tracklet');
                trjs2assign = trjs(ix);
                
                for j=1:length(trjs2assign)
                    trjs2assign(j).ID(1).auto = T.label{j};
                    trjs2assign(j).ID(1).score = T.score(j);
                    trjs2assign(j).ID(1).best_frame = T.best_frame(j);
                end
            end
            
            % manual ids
            f = [Trck.labelsdir,'manualids.csv'];
            if exist(f,'file')
                T = readtable(f);
            else
                return
            end
            
            if isempty(T)
                return
            end
            
            ix = ismember(T.tracklet,trjnames);
            T = T(ix,:);
            
            if isempty(T)
                return
            end
            
            ix=cellfun(@(x) find(strcmp(x,trjnames)),T.tracklet');
            trjs2assign = trjs(ix);
            
            for j=1:length(trjs2assign)
                trjs2assign(j).ID(1).manual = T.label{j};
                trjs2assign(j).ID(1).manual_flip = T.flip(j);
                trjs2assign(j).ID(1).manual_framenum = T.framenum(j);
            end
            
        end
        
        hfig = plot(trjs,varargin);
        plotByID(trjs,Trck)
        play(trjs,Trck);
        montage(trjs,N);
        
    end
    
    methods (Access = protected)

        function set_stats(trj)
            % Compte all kind of statistical measures on the trajectories
            % for fast retrieval
            trj.datai = trj.data_(1,:);
            trj.dataf = trj.data_(end,:);
            trj.nanmeanrarea = nanmean(trj.rarea);
            trj.touching_open_boundry = any(trj.ONBOUNDRY);
            
        end
        
        function close_single_trj(trj)
            
            trj.isopen = false;
            
            % release memory allocation
            trj.data_ = trj.data_(1:trj.len,:);
            if ~isempty(trj.images_) && trj.Trck.get_param('tracking_saveimages')
                trj.images_ = trj.images_(:,:,:,1:trj.len);
            end
            
            % set tf
            trj.tf = trj.ti+trj.len-1;
            
            % calc measures
            trj.set_stats();
            
            % run orientation fix
            trj.data_.ORIENT = -trj.ORIENT;
            if trj.len>1
                trj.fix_orientation();
            end
            
            % set final name
            tistr =[num2str(trj.ti.movnum) '_' num2str(trj.ti.framenum)];
            tfstr =[num2str(trj.tf.movnum) '_' num2str(trj.tf.framenum)];
            newname = [trj.name,'_ti',tistr,'_tf',tfstr];
            trj.rename(newname);
            
            % define the 'exist' sparse vector
            % trj.set_exist;
            
            % save tracklet data
            trj.savedata;
            
            % set colony
            if trj.Trck.get_param('geometry_multi_colony')
                L = trj.Trck.Masks.colony_index_mask;
                cind = L(sub2ind(size(L),round(trj.CENTROID(:,2)),round(trj.CENTROID(:,1))));
                cind = cind(cind>0);
                cind = unique(cind);
                if length(cind)>1
                    report('W','Non unique colony index');
                    cind=NaN;
                elseif isempty(cind)
                    report('W','Outside colony mask');
                    cind=NaN;
                    %                 msk = trj.get_frame_mask;
                    %                 msk = max(msk,[],3);
                    %                 cind = unique(L(msk>0));
                    %                 cind = cind(cind>0);
                    %                 if isempty(cind)
                    %                     cind=0;
                    %                 end
                end
                
            trj.colony = cind;
            if ~isnan(cind)
                trj.colony_label = trj.Trck.colony_labels(cind);
            else
                trj.colony_label = '?';
            end
            end
            
            if trj.isSingle('criteria','maxarea') && trj.Trck.get_param('tracking_saveimages')
                
                % filter frames for classification
                [passed,score] = filter_frames(trj);
                trj.Trck.G.aux.frame_passed.(trj.name) = passed;
                trj.Trck.G.aux.frame_score.(trj.name) = score;
                
                % rotate images
                for i=1:trj.len
                    or = deg(trj.ORIENT(i));
                    trj.images_(:,:,:,i) = imrotate(trj.images_(:,:,:,i),or-90,'crop');
                end
                 
                trj.saveimages;
                
            end
            
            % clear data
            trj.images_ = [];
            trj.data_ = [];

        end
        
        
        
        function rename(trj,newname)
            % Rename a trajectory, tries also to update the containing
            % graph object. Use with caution...
            
            node = findnode(trj.G.G,trj.name);
            trj.G.G.Nodes.Name{node} = newname;
            trj.name = newname;
            
        end
        
        function PG = getPropertyGroups(trj)
            
            if isscalar(trj)
                
                try
                    pg = struct(...
                        'index',trj.index,...
                        'name',trj.name,...
                        'length',trj.len,...
                        'parents',[num2str(trj.nparents),' [',num2str(torow(trj.parents_index)),']'],...
                        'children',[num2str(trj.nchildren),' [',num2str(torow(trj.children_index)),']'],...
                        'from',[num2str(trj.ti.movnum),'/',num2str(trj.ti.framenum)],...
                        'to',[num2str(trj.tf.movnum),'/',num2str(trj.tf.framenum)]);
                    
                    if ~isnan(trj.nants)
                        pg.nants = trj.nants;
                    end
                    
                    if trj.isSingle
                        pg.single = 'yes';
                    else
                        pg.single = 'no';
                    end
                    
                    if ~isempty(trj.autoID)
                        pg.autoID = [trj.autoID,', score=',num2str(trj.ID.score)];
                    end
                    
                    
                catch
                    pg=struct;
                end
                
            else
                
                pg = {'name','len','ti','tf','nparents','nchildren'};
                
            end
            
            PG = matlab.mixin.util.PropertyGroup(pg);
            
        end
        
    end
    
    %%% set/get methods for dependent properties
    methods
        
        
        function set(trjs,flds,vals)
            
            if iscell(flds) && isscalar(flds) && iscell(vals) && ~isscalar(vals) && all(size(trjs(:))==size(vals(:)))
                for i=1:length(trjs)
                    set@matlab.mixin.SetGet(trjs(i),flds,vals(i));
                end
            else
                set@matlab.mixin.SetGet(trjs,flds,vals);
            end
            
        end
        
        function d = get(trjs,fld,tt)
            
            if isempty(trjs)
                d=[];
                return
            end
            
            d = get@matlab.mixin.SetGet(trjs,fld);
            
            if nargin>2
                
                if isscalar(tt)
                    tt=repmat(tt,size(trjs));
                end
                
                if isscalar(trjs)
                    indx = trjs.time2indx(tt);
                    indx = indx(indx>=1 & indx<=trjs.len);
                    d = d(indx,:);
                else
                    if ~all(size(trjs)==size(tt))
                        error('size of time points array must be the same as the size of trj array')
                    end
                    for i=1:length(trjs)
                        indx = trjs(i).time2indx(tt(i));
                        if isempty(indx) || ~(indx>=1 && indx<=trjs(i).len)
                            error('trj does not contain time point')
                        end
                        dd(i,:) = d{i}(indx,:);
                    end
                    d = dd;
                    
                end
                
                
            end
            
            if iscell(d) && isscalar(d{1})
                d = cell2mat(d);
            end
            
            
        end

        function s = get.dscale(trj)
        
            s = trj.Trck.get_param('geometry_rscale');
            
        end
        
        function m = get.m(trj)
            m = trj.ti.movnum;
        end
        
        
        function tt = get.tt(trj)
            tt = (trj.ti:trj.tf)';
        end
        
        function A = get.AREA(trj)
            A = trj.data_.AREA;
        end
        
        function A = get.BBOX(trj)
            A = trj.data_.BBOX;
        end
        
        function C = get.CENTROID(trj)
            C = trj.data_.CENTROID;
        end
        
        function OR = get.ORIENT(trj)
            OR = trj.data_.ORIENT;
        end
        
        function E = get.ECCENT(trj)
            E = trj.data_.ECCENT;
        end
        
        function MA = get.MAJAX(trj)
            MA = trj.data_.MAJAX;
        end
        
        function OB = get.ONBOUNDRY(trj)
            OB = trj.data_.ONBOUNDRY;
        end
        
        function dt = get.dt(trj)
            dt = trj.data_.dt;
        end
        
        function MZ = get.MAXZ(trj)
            MZ = trj.data_.MAXZ;
        end
        
        function n = get.nparents(trjs)
            n = indegree(trjs(1).G.G,{trjs.name});
        end
        
        function n = get.nchildren(trjs)
            n = outdegree(trjs(1).G.G,{trjs.name});
        end
        
        function parents = get.parents(trj)
            parents = trj.G.trjs(trj.parents_index);
        end
        
        function parents = get.parents_index(trj)
            nodes = cat(1,trj.index);
            parents = arrayfun(@(n) tocol(predecessors(trj.G.G,n)), nodes,'UniformOutput',false);
            parents = cat(1,parents{:});
        end
        
        function children = get.children(trj)
            children = trj.G.trjs(trj.children_index);
        end
        
        function children = get.children_index(trj)
            nodes = cat(1,trj.index);
            children = arrayfun(@(n) tocol(successors(trj.G.G,n)), nodes,'UniformOutput',false);
            children = cat(1,children{:});
        end
        
        function siblings = get.siblings(trj)
            siblings = trj.G.trjs(trj.siblings_index);
        end
        
        function siblings = get.siblings_index(trj)
            siblings = cat(1,trj.parents.children_index);
            siblings = setdiff(cat(1,siblings),trj.index);
        end
        
        function coparents = get.coparents(trj)
            coparents = trj.G.trjs(trj.coparents_index);
        end
        
        function coparents = get.coparents_index(trj)
            coparents = cat(1,trj.children.parents_index);
            coparents = setdiff(cat(1,coparents),trj.index);
        end
        
        function rarea = get.rarea(trj)
            rarea = double(trj.AREA) * trj.dscale^2;
        end
        

        function xy = get.xy(trj)
            xy = trj.CENTROID * trj.dscale;
        end
        
       
        
        function x = get.x(trj)
            x = trj.xy(:,1);
        end
        
        function y = get.y(trj)
            y = trj.xy(:,2);
        end
        
        function cx = get.CX(trj)
            cx = trj.CENTROID(:,1);
        end
        
        function cy = get.CY(trj)
            cy = trj.CENTROID(:,2);
        end
        
        function v = get.v(trj)
            if trj.len<=1
                v = [];
            else
                dr = diff(trj.xy,1);
                v = dr./(repmat(trj.dt(2:end),1,2));
            end
        end
        
        function vx = get.vx(trj)
            vx = trj.v(:,1);
        end
        
        function vy = get.vy(trj)
            vy = trj.v(:,2);
        end
        
        function vnorm = get.vnorm(trj)
            vnorm = sqrt(sum((trj.v).^2,2));
        end
        
        function vang = get.vang(trj)
            vang = angle(atan2(trj.v(:,2),trj.v(:,1)));
        end

        function id = get.finalID(trj)
            if ~isempty(trj.ID) && isfield(trj.ID,'final') && ~isempty(trj.ID.final)
                id = trj.ID.final;
            else
                id = {};
            end
        end
        
        function id = get.propID(trj)
            if ~isempty(trj.manualID)
                id = trj.manualID;
            elseif ~isempty(trj.autoID)
                id = trj.autoID;
            else
                id = '';
            end
        end
        
        function sc = get.propScore(trj)
            if ~isempty(trj.manualID)
                sc = inf;
            elseif ~isempty(trj.autoID)
                sc = trj.ID.score;
            else
                sc = 0;
            end
        end
        
        function id = get.autoID(trj)
            if ~isempty(trj.ID) && isfield(trj.ID,'auto')
                id = trj.ID.auto;
            else
                id = '';
            end
        end
        
        function id = get.manualID(trj)
            if ~isempty(trj.ID) && isfield(trj.ID,'manual')
                id = trj.ID.manual;
            else
                id = '';
            end
        end

        function xi = get.xi(trj)
            xi = trj.xyi(1);
        end
        
        function yi = get.yi(trj)
            yi = trj.xyi(2);
        end
        
        function xf = get.xf(trj)
            xf = trj.xyf(1);
        end
        
        function yf = get.yf(trj)
            yf = trj.xyf(2);
        end
        
        function xyi = get.xyi(trj)
            xyi = trj.Ci*trj.dscale;
        end
        
        function xyf = get.xyf(trj)
            xyf = trj.Cf*trj.dscale;
        end
        
        function Ci = get.Ci(trj)
            Ci = trj.datai.CENTROID(1,:);
        end
        
        function Cf = get.Cf(trj)
            Cf = trj.dataf.CENTROID(end,:);
        end
        
        function fi = get.fi(trj)
            fi = trj.ti.f;
        end
        
        function ff = get.ff(trj)
            ff = trj.tf.f;
        end
                
        
        function [xy,FI,FF,ar,ix,single]=trj_array_xy(trjs)
            
            fi = [trjs.fi]; %#ok<*PROP>
            ff = [trjs.ff];
            FI = min(fi);
            FF = max(ff);
            xy = nan(FF-FI+1,2);
            ar = nan(FF-FI+1,1);
            ix = nan(FF-FI+1,1);
            single = nan(FF-FI+1,1);
            for i=1:length(trjs)
                xy(fi(i)-FI+1:ff(i)-FI+1,:)=trjs(i).xy;
                ar(fi(i)-FI+1:ff(i)-FI+1,:)=trjs(i).rarea;
                ix(fi(i)-FI+1:ff(i)-FI+1,:)=trjs(i).index;
                single(fi(i)-FI+1:ff(i)-FI+1,:)=length(trjs(i).ID.final)==1;
            end
            
            
        end
        
        function [EL,FI,FF]=trj_array_ellipse(trjs)
            
            fi = [trjs.fi];
            ff = [trjs.ff];
            FI = min(fi);
            FF = max(ff);
            a = nan(FF-FI+1,1);
            EL=table(a,a,a,a,a,'VariableNames',{'cx','cy','orient','eccent','majax'});
            ix = a;
            for i=1:length(trjs)
                el = get_ellipse(trjs(i));
                EL(fi(i)-FI+1:ff(i)-FI+1,:) = el;
                ix(fi(i)-FI+1:ff(i)-FI+1,1) = trjs(i).index;
            end
            EL.trjix=ix;
            
        end
        
        function EL = get_ellipse(trj)
            
            if numel(trj)>1
                EL = trj_array_ellipse(trj);
                return
            end
            
            A.cx = trj.CENTROID(:,1);
            A.cy = trj.CENTROID(:,2);
            A.orient = trj.ORIENT;
            A.eccent = trj.ECCENT;
            A.majax = trj.MAJAX;
            EL = struct2table(A);
            
        end
        
        function d = get.data_(trj)
            if isempty(trj.data_) 
                trj.loaddata();
            end
            d = trj.data_;
        end
        
        function d = get.images_(trj)
            if isempty(trj.images_)
                trj.loadimages();
            end
            d = trj.images_;
        end
        
        function mf = get.datafile(trj)
            mf = trj.G.datafile;
        end
        
        function mf = get.imagesfile(trj)
            mf = trj.G.imagesfile;
        end
        
        function trj = saveobj(trj)
            
            if trj.datachanged
                trj.savedata;
            end
            
            if trj.imageschanged
                trj.saveimages;
            end
            
        end
        
        function savedata(trj)
            
            A = table2array(varfun(@single,trj.data_));
            trj.datafile.(trj.name) = A;
            
        end
        
        function loaddata(trj)
            
            A = trj.datafile.(trj.name);
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
            
        function saveimages(trj)
            
            trj.imagesfile.(trj.name) = trj.images_;
            
        end
        
        function loadimages(trj)
            
            w = whos(trj.imagesfile);
            w = {w.name};
            if ismember(trj.name,w)
                trj.images_ = trj.imagesfile.(trj.name);
            end
            
        end  
        
        function cleardata(trjs)
            
            for i=1:length(trjs)
                trjs(i).data_ = [];
                trjs(i).images_ = [];
            end
        end
        
    end
    
    methods
        fix_orientation(trj);
        ims = get_image_from_vid(trj,tt);
        [passed,score] = filter_frames(trj);
    end
    

    
end


function DATA = init_tracklet_data(K)

s.AREA = zeros(K,1,'int32');
s.CENTROID = nan(K,2);
s.MAJAX = nan(K,1);
s.ECCENT = nan(K,1);
s.ORIENT = angle(nan(K,1));
s.MAXZ = zeros(K,1,'uint8');
s.BBOX = zeros(K,4,'int32');
s.PERIMETER = nan(K,1);
s.MEANZ = nan(K,1);
s.MAXZ = nan(K,1);
s.MAXINT = nan(K,1);
s.MEANINT = nan(K,1);
s.ONBOUNDRY = false(K,1);

s.dt = nan(K,1);

DATA = struct2table(s);


end



