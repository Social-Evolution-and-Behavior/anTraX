classdef trhandles < handle &  matlab.mixin.SetGet & matlab.mixin.CustomDisplay
    % This class hold all the information used in the tracking process, and
    % is used as a common variable space for all functions.
    
    properties
        
        %%% info fields
        
        expdir = ''                 % the main directory of the experiment
        trackingdirname = 'antrax'
        filename char           % filename of Trck
        
        
    end
    
    properties (Transient=true,Hidden)
        
        
        % parameter structures are saved and loaded from differnt files
        prmtrs struct
        labels struct
        Backgrounds struct
        Masks struct  
        
        er expreader  
        G 
        manualIDs = table({},{},{},{},{},{},{},'VariableNames',{'tracklet','label','flip','framenum','m','len','colony'})
        imagesfile_ = {}
        datafile_ = {}
        
        currfrm = struct('movnum',0,'antblob',antblobobj(),'t',trtime.empty,'CData',[],'dat',struct)
        prevfrm = struct('movnum',0,'antblob',antblobobj(),'t',trtime.empty,'CData',[],'dat',struct)
        ConnectArray
        ConnectArraybin
        frames2go               % number of frame left to track in session
        ExpData                 % contains data about the experiment dt,Temp,RH,etc...
        last_trj_frames
        last_trj_ims
        last_trj tracklet
        
        %%% run time stuff

        hblobs                  % vision.BlobAnalysis object
        of                      % optical flow object for linking
        opticalFlow
        tmp
        
    end
    
    properties (Dependent)
        
        %%% aliases for subdirecories
        
        expname
        trackingdir
        paramsdir
        trackletdir
        imagedir
        graphdir
        labelsdir
        classdir  
        
        
        %%% aliases for easy access to usefull experiment info
        NIDs
        usedIDs
        allLabels
        tagcolors
        Ncolonies
        movlist
        graphlist
        TrackingMask 
        colony_labels
        bg
        
    end
    
    methods
        
        
        function Trck = trhandles(expdir,trackingdirname)
            
            if isa(expdir,'trhandles')
                Trck=expdir;
                return
            end
            
            if ~isfolder(expdir)
                Trck=trhandles.empty;
                report('E','No such directory')
                return
            end
            
            ss = find_sessions(expdir);
            
            if nargin<2 && ~isempty(ss)
                trackingdirname = ss{1};
            elseif nargin<2
                trackingdirname = 'antrax';
            end
            
            % see if already exist
            filename = [expdir,filesep,trackingdirname,filesep,'/parameters/Trck.mat'];
            
            if exist(filename,'file')
                report('I','Loading tracking session from expdir');
                Trck = trhandles.load(expdir,trackingdirname);
                return
            else
                report('I','Creating new tracking session');
            end
            
            Trck.expdir = expdir;
            
            Trck.trackingdirname = trackingdirname;
            
            create_tracking_directory(Trck);

            Trck.load_params;
            
            switch nargin
                case 0
                    % this is the 'blank object' init
                case 1
                    % init for expdir
                    Trck.set_er;
                    Trck.validate(expdir);
                    init_ba_obj(Trck);
                    init_of_obj(Trck);
                case 2
                    % init for expdir
                    Trck.set_er;
                    Trck.validate(expdir);
                    init_ba_obj(Trck);
                    init_of_obj(Trck);
            end
                        
            Trck.load_masks;
            Trck.save
            
        end
        
        prmtrs = default_params(Trck);
        p = get_param(Trck,pname);
        set_param(Trck,pname,pval);
        load_params(Trck);
        save_params(Trck,suffix);
        export_params(Trck, filename);
        import_params(Trck, filename);
        reset_params(Trck);
        save_labels(Trck);
        load_labels(Trck);
        b = is_param(Trck,pname);
        
        function import(Trck,expdir_ref)
            
            Trck_ref = trhandles.load(expdir_ref);
            
            if strcmp(Trck.trackingdir,Trck_ref.trackingdir)
                report('E','target and ref are the same tracking session')
                return
            end
            
            Trck.prmtrs = Trck_ref.prmtrs;
            Trck.labels = Trck_ref.labels;
            Trck.save_params;
            try
                copyfile([Trck_ref.paramsdir,'backgrounds'],[Trck.paramsdir,'backgrounds']); 
            catch
                report('W','No background file found in source')
            end
            try
                copyfile([Trck_ref.paramsdir,'masks'],[Trck.paramsdir,'masks']); 
            catch
                report('W','No mask file found in source')
            end    
            Trck.load_masks;
            Trck.load_bg;
            Trck.save_params;
            Trck.save;
            
            
        end
        
        function save_masks(Trck)
           
            mskdir = [Trck.paramsdir,'masks',filesep];
            mkdirp(mskdir);
            
            % save roi mask
            if isfield(Trck.Masks,'roi')
                imwrite(Trck.Masks.roi*255,[mskdir,'roimask.png']);
            end
            
            % save boundry masks
            if isfield(Trck.Masks,'open_boundry')
                imwrite(Trck.Masks.open_boundry*255,[mskdir,'openboundrymask.png']);
                imwrite(Trck.Masks.open_boundry_perimeter*255,[mskdir,'openboundryperimmask.png']);
            end
               
            % save colony masks
            if Trck.get_param('geometry_multi_colony') && Trck.Ncolonies==size(Trck.Masks.colony,3)
            for i=1:Trck.Ncolonies
                imwrite(repmat(Trck.Masks.colony(:,:,i)*255,[1,1,3]),[mskdir,'colony_',Trck.colony_labels{i},'.png']);
            end
            
            Trck.Masks.colony_index_mask = sum(Trck.Masks.colony.*repmat(reshape(1:Trck.Ncolonies,1,1,[]),size(Trck.Masks.colony,1),size(Trck.Masks.colony,2)),3);
            imwrite(uint8(Trck.Masks.colony_index_mask),[mskdir,'colony_index_mask.png'])
            imwrite(label2rgb(Trck.Masks.colony_index_mask),[mskdir,'colony_color_map.png'])
            
            label_map = im2double(Trck.Masks.roi*255);            
            
            for i=1:Trck.Ncolonies
                s = regionprops(Trck.Masks.colony(:,:,i),'Centroid');
                cent = s.Centroid;
                label_map = insertText(label_map,cent-18,[num2str(i),' ',Trck.colony_labels{i}],'TextColor','red','FontSize',36,'BoxOpacity',0);
            end 
            imwrite(label_map,[mskdir,'colony_label_map.png'])
            
            end
      

            
        end
        
        function load_masks(Trck)
           
            mskdir = [Trck.paramsdir,'masks',filesep];
            if ~exist([mskdir,'roimask.png'],'file')
                Trck.Masks(1).roi = ones([Trck.er.height,Trck.er.width,Trck.er.nchannels],'uint8');
                Trck.Masks.reflection = zeros(size(Trck.Masks.roi),'uint8');
                Trck.Masks.tracking = Trck.Masks.roi;
                Trck.Masks.hshift = 0;
                Trck.Masks.vshift = 0;
                Trck.Masks.open_boundry = zeros(size(Trck.Masks.roi),'uint8');
                Trck.Masks.open_boundry_perimeter = zeros(size(Trck.Masks.roi),'uint8');
                return
            end

            roi = imread([mskdir,'roimask.png']);
            Trck.Masks(1).roi = uint8(roi>0);  
            Trck.Masks.reflection = ones(size(roi),'uint8');
            Trck.Masks.tracking = Trck.Masks.roi;
        
            if exist([mskdir,'openboundrymask.png'],'file')
                msk = uint8(imread([mskdir,'openboundrymask.png'])>0);
                Trck.Masks.open_boundry = msk;
                msk = uint8(imread([mskdir,'openboundryperimmask.png'])>0);
                Trck.Masks.open_boundry_perimeter = msk;
            end
            
            if Trck.get_param('geometry_multi_colony')
                
                Trck.Masks.colony_index_mask = imread([mskdir,'colony_index_mask.png']);
                for i=1:Trck.Ncolonies
                   Trck.Masks.colony(:,:,i) =  Trck.Masks.colony_index_mask==i;
                end
                
            end
           
        end
        
        function load_bg(Trck)
            
            % load all background frames
            bgdir = [Trck.paramsdir,'backgrounds',filesep];
            bgfile = [bgdir,'background.png'];
            if exist(bgfile,'file')
                Trck.Backgrounds(1).bg = imread(bgfile);
            else
                report('W','No background file found');
                return
            end
                
                
            Trck.Backgrounds(1).bg_single = im2single(Trck.Backgrounds.bg);
            for k=1:3
                Trck.Backgrounds(1).white(:,:,k) = wiener2(Trck.Backgrounds(1).bg_single(:,:,k),[10 10]);
            end
          
            if Trck.get_param('background_per_subdir')
                for i=1:length(Trck.er.subdirs)
                    bgfile = [bgdir,'background_',Trck.er.subdirs(i).name,'.png'];
                    if ~exist(bgfile,'file')
                        report('W','background_per_subdir option set, but no per-subdir backgound files found');
                    end
                    Trck.Backgrounds.subdir_bg(:,:,:,i) = imread(bgfile);
                    Trck.Backgrounds.subdir_bg_single(:,:,:,i) = im2single(Trck.Backgrounds.subdir_bg(:,:,:,i));
                    for k=1:3
                        Trck.Backgrounds.subdir_white(:,:,k,i) = wiener2(Trck.Backgrounds.subdir_bg_single(:,:,k,i),[10 10]);
                    end
                end
            end
            
         
            
        end
        
        function a=isfield(obj,f)
            % support the struct syntax 'isfield'
            a = isprop(obj,f);
        end
                
        function validate(Trck,expdir)
            
            if ~strcmp(filesep,expdir(end))
                expdir=[expdir,filesep];
            end
            
            if ~isfolder(expdir)
                report('E',['Could not access expdir ',expdir]);
                return
            end
            
            if ~strcmp(Trck.expdir,expdir)
                Trck.change_expdir(expdir);
            end
            
          
            
        end
        
        
        function change_expdir(Trck,newexpdir)
            % change the experimental directory location, and update all
            % dependent file paths in structure
            
            if ~isfolder(newexpdir)
                report('E',['Could not access expdir ',newexpdir]);
                return
            end
            
            if newexpdir(end)~=filesep
                newexpdir=[newexpdir,filesep];
            end
            
            oldexpdir = Trck.expdir;
            Trck.expdir = strrep(Trck.expdir,oldexpdir,newexpdir);
            Trck.er.expdir = Trck.expdir;
        end
        
        
        function save(Trck,filename)
            % save Trck to file. default location is
            % <expdir>/tracking/parameters/Trck.mat
            
            if nargin<2
                d = Trck.paramsdir;
                if ~exist(d,'dir')
                    mkdir(d);
                end
                filename=[d,'Trck.mat'];
            end
            
            % save params
            Trck.save_params;
            
            % save first to tmp file to minimize chances of contention with
            % other job read
            ftmp = [filename,'.tmp'];
            save(ftmp,'Trck','-mat');
            movefile(ftmp,filename);
            
        end
        
        function reset_frame_structures(Trck)
            Trck.currfrm = struct('movnum',0,'antblob',antblobobj(),'t',trtime.empty,'CData',[],'dat',struct);
            Trck.prevfrm = struct('movnum',0,'antblob',antblobobj(),'t',trtime.empty,'CData',[],'dat',struct);
        end
        
        function set_er(Trck,varargin)
            
            p = inputParser;
            addOptional(p,'reader',Trck.get_param('videos_reader'),@(x) ismember(x,{'ffreader','VideoReader','default'}));
            addParameter(p,'bufsz',50,@(x) x>=0);
            parse(p,varargin{:});
            
                           
            Trck.er = expreader(Trck.expdir,Trck.trackingdirname,'reader',Trck.get_param('videos_reader'),'bufsz',p.Results.bufsz);

        end
        
        function read(self,varargin)
            self.read_frame(varargin{:});
        end
        
        function frame = read_frame(Trck,f)
            Trck.prevfrm = Trck.currfrm;
            Trck.currfrm = struct('movnum',0,'antblob',antblobobj(),'t',trtime.empty,'CData',[],'dat',struct);
            if isa(f,'trtime')
                Trck.currfrm.t = f;
                f = Trck.currfrm.t.absframe;
            else
                Trck.currfrm.t = trtime(Trck,f);
            end
            [Trck.currfrm.movnum,Trck.currfrm.framenum] = Trck.er.get_m_mf(f);
            [Trck.currfrm.CData,Trck.currfrm.dat] = Trck.er.read_frame(f);
            Trck.currfrm.single = im2single(Trck.currfrm.CData);
            Trck.currfrm.filteredGrayIm = [];
            
            Trck.currfrm.t.interval = Trck.currfrm.dat.dt;
            if ~isempty(Trck.prevfrm.t)
                Trck.currfrm.t.realtime = Trck.prevfrm.t.realtime + Trck.currfrm.dat.dt;
            else
                Trck.currfrm.t.realtime = 0;
            end
            
            if nargout>0
                frame = [Trck.currfrm.CData];
            end
        end
        
        function [XY, frames] = loadxy(Trck,varargin)
            
            p = inputParser;

            addRequired(p,'Trck',@(x) isa(x,'trhandles'));
            addParameter(p,'movlist','all',@(x) isnumeric(x) || strcmp(x,'all'))
            addParameter(p,'colony','all',@ischar)
            addParameter(p,'type','final',@(x) ismember(x,{'final','untagged','noprop'}));
            parse(p,Trck,varargin{:});
            
            
            xydir = [Trck.trackingdir,'antdata',filesep];
            
            
            if Trck.get_param('geometry_multi_colony')  && strcmp(p.Results.colony,'all')
                
                for i=1:Trck.Ncolonies
                    c = Trck.colony_labels{i};
                    [XY.(c),frames] = Trck.loadxy(movlist,c,varargin);
                end
                return 
                
            end
            
            
            if Trck.get_param('geometry_multi_colony')
                
                xydir = [xydir,p.Results.colony,filesep];
            
            end
            
            
            if strcmp(p.Results.movlist,'all')
               
                movlist = Trck.graphlist;
                
            else
                
                movlist = p.Results.movlist;
                
            end
            
            
            switch p.Results.type
                
                case 'final'
                    
                    sfx = '';
                    
                case 'noprop'
                    
                    sfx = '_noprop';
                    
                case 'untagged'
                    
                    sfx = 'untagged';
                    
            end
            
            
            xyfiles = {};
            
            for i=1:length(movlist)
                m = movlist(i);
                splitted = exist([xydir,'xy_',num2str(m),'_',num2str(m),'_p1.mat'],'file');
                if ~splitted
                    xyfiles{end+1} = ['xy_',num2str(m),'_',num2str(m),sfx,'.mat'];
                else
                    a = dir([xydir,'xy_',num2str(m),'_',num2str(m),'_p*', sfx ,'.mat']);
                    a = {a.name};
                    f1 = @(x) strsplit(x(1:end-4),'_p');
                    f2 = @(x) str2double(x{2});
                    p = cellfun(@(x) f2(f1(x)), a);
                    a = a(argsort(p));
                    xyfiles = cat(2,xyfiles,a);
                end
            end
            %xyfiles = arrayfun(@(x) [xydir,'xy_',num2str(x),'_',num2str(x),'.mat'],movlist,'UniformOutput',false);
            
            for i=1:length(xyfiles)
                xy(i) = load([xydir,xyfiles{i}]);
                frames{i} = tocol(Trck.er.movies_info(movlist(i)).fi:Trck.er.movies_info(movlist(i)).ff);
            end
            
            XY = struct;
            ids = fieldnames(xy(i));
            
            for i=1:length(ids)
                XY(1).(ids{i}) = cat(1,xy.(ids{i}));
            end
            
            frames = cat(1,frames{:});
            
        end
             
        function [G,movlist] = loaddata(Trck,movlist,colony)
            
            if nargin==1 || isempty(movlist) || (ischar(movlist) && strcmp(movlist,'all'))
                movlist=1:Trck.er.nmovies;
            end
            
            if nargin<3 || isempty(colony) || ~Trck.get_param('geometry_multi_colony') 
                colony='';
            elseif isnumeric(colony) && colony>Trck.Ncolonies
                report('E','No such colony index')
                return
            elseif ~(isnumeric(colony) || ismember(colony,Trck.colony_labels) || strcmp(colony,'all'))
                report('E','No such colony labels')
                return                
            end
            
            if isempty(colony) && Trck.get_param('geometry_multi_colony')
                report('E','Multi colony experiment, colony input required')
                G=[];
                movlist=NaN;
                return
            end
            
            if strcmp(colony,'all') && Trck.get_param('geometry_multi_colony')
                for i=1:Trck.Ncolonies
                    c = Trck.colony_labels{i};
                    gs = trgraph.load(Trck,movlist,c);
                    GS(i)=trgraph.merge(gs);
                end
            elseif ~Trck.get_param('geometry_multi_colony')
                GS = trgraph.load(Trck,movlist);
            else
                GS = trgraph.load(Trck,movlist,colony);
            end
                        
            Trck.G = trgraph.merge(GS);
            
            G = Trck.G;
                        
        end
        
        function T = loadManualIDs(Trck)
            
            f = [Trck.labelsdir,'manualids.csv'];
            if exist(f,'file')
                T = readtable(f);
                Trck.manualIDs = T;
            else
            end
            
        end
        
        function saveManualIDs(Trck,T)
            
            if nargin<2
                T = Trck.manualIDs;
            end
            
            f = [Trck.labelsdir,'manualids.csv'];
            mkdirp(Trck.labelsdir);
                
            if isempty(T)
                report('W','Empy manualIDs table, not saving')
            end
            writetable(T,f);
            
        end
        
        
        
        % function defined externally
        
        init_ba_obj(Trck);
        init_of_obj(Trck);
        AntXY = getAntXY(Trck,ids,from,to);
        
    end
    
    
    %%% get/set methods
    methods
        
        function groups = get_solve_groups(Trck)
            
            
            switch Trck.get_param('graph_groupby')
            
                
                % whole experiment
                case 'experiment'
                    
                    groups{1} = Trck.movlist;
                    
                case 'wholeexperiment'
                    
                    groups{1} = Trck.movlist;
            
                % by subdir
                case 'subdir'
                    
                    for i=1:length(Trck.er.subdirs)
                       
                        groups{i} = Trck.er.subdirs(i).mi:Trck.er.subdirs(i).mf;
                        
                    end
            
                % individual
                case 'movie'
                    
                    groups = num2cell(Trck.movlist);
            
                % custom
                case 'custom'
                    
                    error('not implemented')
                    groups = {}
            end
            
            
            for i=1:length(groups)
               
                groups{i} = intersect(groups{i},Trck.graphlist);
                
            end
            
        end
        
        function ename = get.expname(Trck)
            
            d = Trck.expdir;
            
            if strcmp(d(end),filesep)
                d = d(1:end-1);
            end
            
            parts = strsplit(d,filesep);
            ename = parts{end};
            
        end
        
        function d = get.trackingdir(Trck)
            d = [Trck.expdir,Trck.trackingdirname,filesep];
        end
        
        function d = get.imagedir(Trck)
            d = [Trck.trackingdir,'images',filesep];
        end
        
        function d = get.labelsdir(Trck)
            d = [Trck.trackingdir,'labels',filesep];
        end
        
        function d = get.trackletdir(Trck)
            d = [Trck.trackingdir,'tracklets',filesep];
        end

        function d = get.graphdir(Trck)
            d = [Trck.trackingdir,'graphs',filesep];
        end
        
        function d = get.paramsdir(Trck)
            d = [Trck.trackingdir,'parameters',filesep];
        end
        
        function d = get.classdir(Trck)
            d = Trck.get_param('classdir');
        end
        
        function set.classdir(Trck,d)
            if ~strcmp(d(end),filesep)
                d = [d,filesep];
            end
            
            Trck.set_param('classdir',d);
            
        end
        
        function msk = get.TrackingMask(Trck)
            msk = Trck.Masks.tracking;
        end
                
        function list = get.graphlist(Trck)
           
            if Trck.get_param('geometry_multi_colony')
                filelist = dir([Trck.graphdir,'/*/graph_*.mat']);
            else
                filelist = dir([Trck.graphdir,'graph_*.mat']);
            end
            list=[];
            for i=1:length(filelist)
                fname = filelist(i).name;
                if contains(fname,'trjs')
                    continue
                end
                mstr = strrep(fname,'graph_','');
                mstr = strrep(mstr,'.mat','');
                mstr = strsplit(mstr,'_');
                if ~strcmp(mstr{1},mstr{2})
                    continue
                end
                mstr = mstr{1};
                list(end+1) = str2num(mstr);
            end
            
            list = unique(sort(list));

        end
                
        function c = get.tagcolors(Trck)
            c = Trck.labels.tagcolors;
        end
        
        function c = get.usedIDs(Trck)
            c = Trck.labels.ant_labels;
        end
        
        function c = get.allLabels(Trck)
            c = [tocol(Trck.labels.ant_labels);tocol(Trck.labels.noant_labels);tocol(Trck.labels.other_labels)];
        end
        
        function NID = get.NIDs(Trck)
            NID = length(Trck.usedIDs);
        end
        
        function mlist = get.movlist(Trck)
            mlist = Trck.er.movlist;
        end
        
        function N = get.Ncolonies(Trck)
            N = Trck.get_param('geometry_Ncolonies');
        end
        
        function lab = get.colony_labels(Trck)
            lab = Trck.get_param('geometry_colony_labels');
        end
        
        function mf = datafile(Trck,m)
            
            if length(Trck.datafile_)<m || ~isa(Trck.datafile_{m},'matlab.io.MatFile')
                Trck.datafile_{m} = matfile([Trck.trackletdir,'trdata_',num2str(m),'.mat'],'Writable',true);
            end
            
            mf = Trck.datafile_{m};
            
        end
        
        function set_all_imagesfiles(Trck)
            
            mlist = Trck.graphlist;
            
            for i=1:length(mlist)
                mf = Trck.imagesfile(mlist(i));
            end
            
        end
        
        function mf = imagesfile(Trck,m)
            
            if length(Trck.imagesfile_)<m || ~isa(Trck.imagesfile_{m},'matlab.io.MatFile')
                Trck.imagesfile_{m} = matfile([Trck.imagedir,'images_',num2str(m),'.mat'],'Writable',true);
            end
            
            mf = Trck.imagesfile_{m};
            
        end
        
        
        function add_post_command(Trck, cmd)
           
            cmds = Trck.get_param('single_video_post_commands');
            if ~ismember(cmd,cmds)
                cmds{end+1} = cmd;
            end
            Trck.set_param('single_video_post_commands',cmds);
            
        end
        
        function remove_post_command(Trck, cmd)
           
            cmds = Trck.get_param('single_video_post_commands');
            if ismember(cmd,cmds)
                cmds(strcmp(cmds,cmd)) = [];
            end
            Trck.set_param('single_video_post_commands',cmds);
                
        end
        
        function [bg,bg_single,white] = get_bg(Trck,m)
            
            if nargin<2
                m=1;
            end
            
            if isa(m,'trtime')
                m = m.m;
            end
            
            if isempty(Trck.Backgrounds)
                Trck.load_bg
            end
            
            switch Trck.get_param('background_kind')
                
                
                
                case 'experiment'
                    
                    bg = Trck.Backgrounds.bg;
                    bg_single = Trck.Backgrounds.bg_single;
                    white = Trck.Backgrounds.white;
                    
                case 'subdir'
                    
                    sd = m>=[Trck.er.subdirs.mi] & m<=[Trck.er.subdirs.mf];
                    bg = Trck.Backgrounds.subdir_bg(:,:,:,sd);
                    bg_single = Trck.Backgrounds.subdir_bg_single(:,:,:,sd);
                    white = Trck.Backgrounds.subdir_white(:,:,:,sd);
                    
                otherwise
                    
                    report('E','Wrong background type')
                    
            end

        end
        
    end
    
    %%% private methods
    methods (Access=protected)
        
        function PG = getPropertyGroups(Trck)
            
            %pgtitle{1} = 'Experiment properties:';
            
            if isempty(Trck)
                PG(1) = matlab.mixin.util.PropertyGroup(struct);
                return
            end
            
            pg{1} = struct('expname',Trck.expname,...
                'session',Trck.trackingdirname,...
                'expdir',Trck.expdir);
            
            try
                pg{1}.Nmovies = Trck.er.nmovies;
            catch
            end
            
            if ~isempty(Trck.Ncolonies)
                pg{1}.Ncolonies = Trck.Ncolonies;
            end
            
            if Trck.get_param('tagged')
                pg{1}.Nants = Trck.NIDs;
            end
                        
            
            PG(1) = matlab.mixin.util.PropertyGroup(pg{1});%,pgtitle{1});
             
            
        end

    end
    
    methods (Static)
        
        function Trck = load(expdir,trackingdirname)
            
            if nargin<2
                trackingdirname = [];
            end
            
            
            if isa(expdir,'trhandles') && (isempty(trackingdirname) || strcmp(expdir.trackingdirname, trackingdirname))
                Trck = expdir;
                return
            end

            if isempty(trackingdirname)
                
                % get list of tracking dirs
                sessions = find_sessions(expdir);
                
                if ~isempty(sessions)
                    trackingdirname = sessions{1};
                else
                    report('E','No valid Trck file to load in expdir')
                    Trck=[];
                    return
                end
                
            end
            
            if ~isfolder(expdir)
                report('E',['Could not access expdir ',expdir]);
                error(['Could not access expdir ',expdir]);
            end
            
            filename = [expdir,filesep,trackingdirname,filesep,'/parameters/Trck.mat'];
            
            if ~exist(filename,'file')
                report('E','Trck file does not exist in expdir');
                error('Trck file does not exist in expdir');
            end
                    
            try
                load(filename,'Trck');
            catch
                report('E','Could not load Trck');
                error('Could not load Trck');
            end
            
            if ~exist('Trck','var')
                report('E','file did not contain a Trck object');
                error('file did not contain a Trck object')
            end
            if ~strcmp(expdir(end),filesep)
                expdir=[expdir,filesep];
            end
            Trck.expdir=expdir;
            Trck.trackingdirname = trackingdirname;
            Trck.load_params;
            Trck.set_er;
            %Trck.validate(expdir);
            Trck.filename = filename;
            Trck.load_bg;
            Trck.load_masks;
            Trck.init_ba_obj;
            Trck.init_of_obj;
        end
        
    end % static methods
    
    
end

    