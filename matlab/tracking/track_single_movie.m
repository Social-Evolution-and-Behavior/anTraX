function track_single_movie(expdir,varargin)


p = inputParser;
addRequired(p,'expdir',@(x) (ischar(x) && isfolder(x)) || isa(x,'trhandles'));
addOptional(p,'m',[],@(x) isnumeric(x)||ischar(x));
addParameter(p,'from',[],@(x) isnumeric(x)||isa(x,'trtime')||ischar(x));
addParameter(p,'to',[],@(x) isnumeric(x)||isa(x,'trtime')||ischar(x));
addParameter(p,'report',1000,@isnumeric);
addParameter(p,'batchparams',[]);
addParameter(p,'path_to_antrax',[]);
addParameter(p,'trackingdirname',[]);
addParameter(p,'moviepart',[]);
addParameter(p,'diary',[]);

% parse inputs
parse(p,expdir,varargin{:});

if ~isempty(p.Results.diary)
    diary(p.Results.diary);
end

Trck = trhandles.load(expdir,p.Results.trackingdirname);
Trck.er.init_buf(0);

%% set frame range to track

m = p.Results.m;
if ischar(m)
    m = str2double(m);
end

from = p.Results.from;
if ischar(from)
    from = str2double(from);
end

to = p.Results.to;
if ischar(to)
    to = str2double(to);
end

if ~isempty(m) && (~isempty(from) || ~isempty(to))
    ti = trtime(Trck,max([from,Trck.get_param('videos_first_frame_to_track')]));
    tf = trtime(Trck,min([to,Trck.er.totalframenum]));
elseif ~isempty(m)
    ti = trtime(Trck,Trck.er.movies_info(m).fi);
    tf = trtime(Trck,Trck.er.movies_info(m).ff);
else
    ti = trtime(Trck,max([from,Trck.get_param('videos_first_frame_to_track')]));
    tf = trtime(Trck,min([to,Trck.er.totalframenum]));
    m = ti.m;
end

if m ~= tf.m || m ~= ti.m
    report('E','ti/tf do not match m');
    return
end


if Trck.get_param('videos_downsample')
    delta = Trck.get_param('videos_downsamplefactor');
    report('I',['Downsample is on: tracking every ',num2str(delta),' frames'])
else
    delta = 1;
end

tt = ti:delta:tf;
N = length(tt);

%% 

% set Linking method
report('I',['Linking method is ',func2str(Trck.get_param('linking_method'))])
linkfun = Trck.get_param('linking_method');

% clear previous data related to the current movie
clear_tracking_data(Trck,m,p.Results.moviepart);

% init data structures
Trck.G = trgraph(Trck);
Trck.G.aux.frame_passed = struct;
Trck.G.aux.frame_score = struct;
Trck.G.ti = ti;
Trck.G.tf = tf;
if ~isempty(p.Results.moviepart)
    Trck.G.filesuffix = ['_p',num2str(p.Results.moviepart)];
end

Trck.tmp.IDlist = [];
Trck.reset_frame_structures();
init_ba_obj(Trck)
init_of_obj(Trck)



if Trck.get_param('segmentation_local_z_scaling')
    [~,~,BGW] = Trck.get_bg(m);
    A = rgb2gray(BGW);
    w = median(A(Trck.TrackingMask(:,:,1)>0));
    ZS = w./BGW;
else
    ZS = [];
end

%% Main Loop

% for each frame between the first and the last
report('I','Starting the frame loop')

for n = 1:N
    
    t = tt(n);
    
    % read the frame, and update the Trck.currfrm, frame number and movie
    % number
    read_frame(Trck,t);
    if strcmp(Trck.er.reader_type,'ffreader') && t.mf>Trck.er.vr.info.nframes
        report('E','No more frames in file - probably a corrupted avi')
        report('E','Stopping tracking loop')
        break
    end
    
    Trck.currfrm.n = n;
    Trck.frames2go = N-n+1;
    
    % blob detection
    detect_blobs(Trck,'ZS',ZS);
    
    % blob linking
    linkfun(Trck);
    
    % Update the trajectories
    update_tracklets(Trck);
    
    if rem(n,p.Results.report)==0
        report('I',['Finished tracking frame #',num2str(t.f),' (',num2str(n),'/',num2str(N),')']);
    end
    
end

report('I','Finished frame loop, cleaning up');

%% Finish and clean up

Trck.G.close;
Trck.G.save;    

% save a copy of run parameters
BI = p.Results.batchparams;
if ~isempty(BI)
    Trck.save_params('last_tracking_run');
end

%% run post processing scripts 

if ~isempty(p.Results.path_to_antrax)
    path_to_antrax = p.Results.path_to_antrax;
elseif isempty(BI)
    path_to_antrax = [fileparts(mfilename('fullpath')),'/../../'];
else
    path_to_antrax = BI.path_to_antrax;
end
    
if Trck.get_param('tracking_classifyaftertracking')
    classify_batch(Trck,'NumWorkers',2,'movlist',m,'path_to_antrax',path_to_antrax);
end

post_commands = Trck.get_param('single_video_post_commands');

for i=1:length(post_commands)
    eval([post_commands{i},'(Trck.G);']);
end
    

%% things to be done if this is the last job to finish in a batch

if isempty(BI) || ~isempty(setdiff(BI.movlist,Trck.graphlist))
    report('G','Done!');
    return
end

report('I','Last task to finish, linking across movies')

link_across_movies(Trck,'reset',true);

post_commands = Trck.get_param('tracking_post_command');

for i=1:length(post_commands)
    eval([post_commands{i},'(Trck);']);
end

report('G','Done!');
diary off
