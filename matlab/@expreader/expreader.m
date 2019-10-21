% 'expreader' class to handle accsess to all videos of experiment
%
% Create object (and init - might take some time):
%   er = expreader(expdir,type
%
% Read next frame:
%   frame,dat = er.read_frame()
%
% Read specific frame:
%   frame,dat = er.read_frame(f)
%   frame,dat = er.read_frame(m,mf); 
%
% Get list of frames in movie:
%   f_list = er.get_f_list(m)
%
% Save object:
%   er.save(filename)
%

classdef expreader < handle &  matlab.mixin.SetGet & matlab.mixin.CustomDisplay
    
    properties
        
        expdir          % experiment directory from which to read videos
        videodir
        expname         % name of the experiment
        trackingdirname
        reader_type     % class of video reader object
        datflds         % fields of dat file
        buf_sz = 2      % number of frames to buffer
        
        nmovies         % number of movies in the experiment
        frame_size      % frame size
        nchannels=3     % number of channels
        
        movies_info     % per-movie information
        subdirs
        
        mask = []       % mask to be applied for read images
        tform = []      % transform to be applied to read images
        bgframe = []    % background frame of the experiment
        
        firstframefortracking
        
    end %  properties
    
    properties (Transient)
        
        vr
        
        last_tt trtime
        last_f = -1      % last frame number read
        last_frame0      % last frame image read
        last_frame       % last processed frame
        last_dt
        last_ts = NaN;
        last_dat
        
        buf uint8
        buf_f 
        buf_ix = 1
        
        cur_mov_ix      % index of currently open movie
        cur_mov_name    % name of currently open movie
        cur_exp_data
        cur_exp_data_m
        
    end
    
    properties (Dependent)
        
        width
        height
        totalframenum
        numofmovies
        VideoReader
        last_mf
        last_m
        fps
        framerate
        ti
        tf
        
        movies_info_file
        movlist

    end
    
    methods
        
        function er = expreader(expdir,varargin)
            
            p = inputParser;
            
            addOptional(p,'expdir','',@ischar);
            addOptional(p,'trackingdirname','tracking',@ischar);
            addParameter(p,'reader','default',@ischar);
            addParameter(p,'datflds',{'dt'},@iscell);
            addParameter(p,'bufsz',2,@(x) x>=0);
            addParameter(p,'force',false,@islogical);
            
            parse(p,expdir,varargin{:});
            
            if strcmp(p.Results.reader,'default')
                er.reader_type = 'ffreader';
            else
                er.reader_type = p.Results.reader;
            end
            
            if isempty(p.Results.expdir)
                er.expdir = uigetdir;
            else
                er.expdir = expdir;
            end
            
            % extract expname from expdir
            if er.expdir(end)==filesep, er.expdir=er.expdir(1:end-1); end
            [~,er.expname,~] = fileparts(er.expdir);
            er.expdir = [er.expdir,filesep];
            
            er.trackingdirname = p.Results.trackingdirname;
            
            if isfolder([er.expdir,'videos'])
                er.videodir = [er.expdir,'videos',filesep];
            else
                er.videodir = er.expdir;
            end
            
            er.init(p.Results.force);
            er.buf_sz = p.Results.bufsz;
            er.datflds = p.Results.datflds;
            
            init_buf(er);
            
        end % constructor
        
        function init_buf(er,buf_sz)
            
            if nargin>1
                er.buf_sz = buf_sz;
            end
            
            % initialize buffer
            er.buf = zeros([er.height,er.width,3,er.buf_sz],'uint8');
            er.buf_f = zeros(er.buf_sz,1);
            er.buf_ix = 1;
        end
        
        function [m,mf] = get_m_mf(er,f)
            % get movie index and movie frame of frame f
            m = find(f>=[er.movies_info.fi],1,'last');
            mf = f - [er.movies_info(m).fi]' + 1;
        end
        
        function [f] = get_f(er,m,mf)
            % get frame number f of frame mf in movie m
            f = [er.movies_info(m).fi]' + mf - 1;
        end
        
        function f_list = get_f_list(er,m)
            % get the frame list of movie m
            f_list = er.movies_info(m).fi:er.movies_info(m).ff;
            
        end
        
        function T = read_dat_movlist(er, movlist)
            
            T = table();
            for m=movlist
                Tm = read_dat_file(datfile(er,m));
                ix = 1:size(Tm,1);
                T = [T;Tm];
            end
            
        end
        
        function T  = read_dat(er,t,flds)
            
            if nargin<2 || isempty(t) || (ischar(t) && strcmp(t,'all'))
                T = read_dat_movlist(er, er.movlist);
                if nargin>2
                    T = T(:,flds);
                end
                return
            end

            if ~isa(t,'trtime')
                t = trtime(er,t);
            end            
            
            T = table();
            for m=t(1).m:t(end).m
                Tm = read_dat_file(datfile(er,m));
                ix = 1:size(Tm,1);
                if m==t(1).m
                    ix = ix(ix>=t(1).mf);
                end
                if m==t(end).m
                    ix = ix(ix<=t(end).mf);
                end
                Tm = Tm(ix,:);
                T = [T;Tm];
            end

            if nargin>2
                T = T(:,flds);
            end
            
        end
                
            
        
        function [frame,dat] = read(er,varargin)

            [frame,dat] = er.read_frame(varargin{:});
            
        end
        
        function [frame,dat] = read_frame(er,varargin)
            % Read frame of experiment.
            %
            % Read next frame:
            %   frame = er.read_frame()
            %
            % Read frame f:
            %   frame = er.read_frame(f)
            %
            % Read frame mf of movie m:
            %   frame = er.read_frame(m,mf)
            %
            % Read also frame info from dat file:
            %   [frame,dat] = er.read_frame(...)
            
            p = inputParser;
            addRequired(p,'er');
            addOptional(p,'f',er.last_f+1);            
            parse(p,er,varargin{:});
            
            if isa(p.Results.f,'trtime')
                t = p.Results.f;
                f = p.Results.f.absframe;
            elseif numel(p.Results.f)==1
                f = p.Results.f;
                t = trtime(er,f);
            else
                m = p.Results.f(1);
                mf = p.Results.f(2);
                f = er.get_f(m,mf);
                t = trtime(er,f);
            end
            
            er.fetch_frame(t);
            er.fetch_dat(t);           
            
            % explicit return
            if nargout>0
                frame = er.last_frame;
            end
            if nargout>1
                dat = er.last_dat;
            end
            
            
        end
        
        
        function dat = fetch_dat(er,t)
            
            prev_ts = er.last_ts;
           
            if ~t.m==er.cur_exp_data_m
                update_cur_exp_data(er,t.m);
            end
            
            if ~isempty(er.cur_exp_data)
                dat = table2struct(er.cur_exp_data(t.mf,:));
            else
                dat = struct;
            end
            
            % always return dt as 1/fps, even when no dat file exist
            if ~isfield(dat,'dt')
                dat.dt = 1/er.movies_info(er.cur_mov_ix).fps;
            end
            
            if ~isfield(dat,'interrupt')
                dat.interrupt = 0;
            end

            if isfield(dat,'timestamp')
                er.last_ts = dat.timestamp;
            elseif isfield(dat,'time')
                er.last_ts = dat.time;
            else
                er.last_ts = NaN;
            end

            dat.tracking_dt = er.last_ts - prev_ts;
            
            if isnan(dat.tracking_dt)
                dat.tracking_dt = dat.dt;
            end
                
            er.last_dt = dat.dt;
            er.last_dat = dat;
            

        end
        
        function fetch_frame(er,t)
            
            f = t.f;
            m = t.m;
            mf = t.mf;
            
            % check in buffer
            if er.buf_sz>0 && ismember(f,er.buf_f)
                er.last_frame0 = er.buf(:,:,:,er.buf_f==f);
                er.last_tt = t;
                er.last_f = f;
                er.last_frame = er.last_frame0;
                return
            end
            
            % if needed, open new file
            if isempty(er.vr)||er.cur_mov_ix~=m
                er.open_vid(m);
            end
            
            try
                % try to read
                er.last_frame0 = er.vr.read(mf);
            catch
                % if error, try to recreate video reader object
                report('W','VideoReader error, recreating object..');
                er.vr = er.VideoReader(er.cur_mov_name);
                er.last_frame0 = er.vr.read(mf);
                
            end
            if isempty(er.last_frame0)
                report('W',['expreader: corrupt frame #',num2str(f)])
            end
            er.last_tt = t;
            er.last_f = f;
            
            % update buffer
            if ~isempty(er.last_frame0) && er.buf_sz>0
                er.buf(:,:,:,er.buf_ix)=er.last_frame0;
                er.buf_f(er.buf_ix)=f;
                er.buf_ix = er.buf_ix+1;
                if er.buf_ix>er.buf_sz
                    er.buf_ix=1;
                end
            end
            er.last_frame = er.last_frame0;
            
            
        end
        
        function f = movfile(er,m)
            
            f = [er.videodir,filesep,er.movies_info(m).subdir,filesep,er.movies_info(m).movfile];
            
        end
        
        function f = datfile(er,m)
            
            f = [er.videodir,filesep,er.movies_info(m).subdir,filesep,er.movies_info(m).datfile];
            
        end
        
        function open_vid(er,m)
            
            warning('OFF', 'MATLAB:table:ModifiedAndSavedVarnames')
            
            er.cur_mov_ix = m;
            er.cur_mov_name = er.movfile(m);
            report('I',['opening video file ',er.cur_mov_name]);
            if strcmp(er.reader_type,'stupid_bug')
                er.vr = ffreader(er.cur_mov_name);
            end
            er.vr = er.VideoReader(er.cur_mov_name);
            update_cur_exp_data(er,m);
        end
        
        function update_cur_exp_data(er,m)
            
            if isfield(er.movies_info(m),'datfile')
                er.cur_exp_data = read_dat_file(er.datfile(m),er.datflds);
                er.cur_exp_data_m = m;
            else
                er.cur_exp_data = table();
                er.cur_exp_data_m = m;
            end            
        end
        

        function dt = get_intervals(er,tt)
            % Returns the interframe interval of trtime array tt
            
            dt = nan(size(tt));
            
            movies = unique([tt.m]);
            
            for m = movies
                er.read([m,1]);
                ttm = tt([tt.m]==m);
                frames = [ttm.mf];
                dt([tt.m]==m) = er.cur_exp_data.dt(frames);
            end
                
            
            
        end
        
        
        function save(er,filename)
            if nargin==1
                save([er.expdir,'/expreader.mat'],'er');
            else
                save(filename,'er');
            end
        end
        
        function w = get.width(er)
            w=er.frame_size(2);
        end
        
        function h = get.height(er)
            h=er.frame_size(1);
        end
        

        function n = get.totalframenum(er)
            n = sum([er.movies_info.nframes]);
        end
        
        function n = get.numofmovies(er)
            n = length(er.movies_info);
        end
        
        function mf = get.last_mf(er)
            [~,mf] = er.get_m_mf(er.last_f);
        end
        
        function m = get.last_m(er)
            [m,~] = er.get_m_mf(er.last_f);
        end
        
        function fps = get.framerate(er)
            fps = er.movies_info(1).fps;
        end
        
        function fps = get.fps(er)
            fps = er.movies_info(1).fps;
        end
        
        function fh = get.VideoReader(er)
            fh = eval(['@',er.reader_type]);
        end
        
        function ti = get.ti(er)
            ti = trtime(er,er.movies_info(1).fi);
        end
        
        function tf = get.tf(er)
            tf = trtime(er,er.movies_info(end).ff);
        end
        
        function f = get.movies_info_file(er)
            f = [er.expdir,filesep,er.trackingdirname,filesep,'parameters',filesep,'movies_info.txt'];
        end
        
        function mlist = get.movlist(er)
            mlist = [er.movies_info.index];
        end
        
    end % methods
   
    methods (Access = protected)
        
        init(er,force)
       
        
        function PG = getPropertyGroups(er)
            
            if isfield(er.movies_info,'datfile')
                hasdat = 'yes';
            else
                hasdat = 'no';
            end
            
            pg{1} = struct('reader',er.reader_type);
            PG(1) = matlab.mixin.util.PropertyGroup(pg{1});
            
            pgtitle{2} = 'Experiment properties:';
            pg{2} = struct('expname',er.expname,...
                'expdir',er.expdir,...
                'nmovies',er.nmovies,...
                'nchannels',er.nchannels,...
                'width',er.width,...
                'height',er.height,...
                'framerate',er.fps,...
                'totalframenum',er.totalframenum,...
                'datfiles',hasdat);
            
            PG(2) = matlab.mixin.util.PropertyGroup(pg{2},pgtitle{2});
            
            if ~isempty(er.vr)
                pgtitle{3} = 'Current movie properties:';
                pg{3} = struct('index',er.cur_mov_ix,...
                    'file',er.cur_mov_name,...
                    'last_frame_read',er.last_f,...
                    'last_movie_frame',er.last_mf);
                
                
                PG(3) = matlab.mixin.util.PropertyGroup(pg{3},pgtitle{3});
            end
            
            
        end
        
        
        
    end
    
    

end % classdef


function T = read_dat_file(filename,datflds)

    if ~exist(filename,'file')
        T = table;
        return
    end


    T = readtable(filename);
    
    % check if file has a header
    fd = fopen(filename);
    line = fgets(fd);
    fclose(fd);

    if line(1)=='%'
        datflds = strsplit(strtrim(line(2:end)),'\t');
        if length(datflds)>size(T,2)
            datflds=datflds(1:size(T,2));
        end
    end
    
    if exist('datflds','var')
        T.Properties.VariableNames(1:length(unique(datflds))) = unique(datflds,'stable'); 
    end

end














