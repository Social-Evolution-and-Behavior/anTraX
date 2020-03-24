function make_cropped__ant_centered_video(Trck, id, fi, ff, varargin)

p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addRequired(p,'id', @(x) ismember(x, Trck.usedIDs));
addRequired(p,'fi');
addRequired(p,'ff');

addParameter(p,'size',[120,160],@isnumeric);
addParameter(p,'m',[],@isnumeric);

addParameter(p,'speedup',1,@isnumeric);

addParameter(p,'track',true,@islogical);
addParameter(p,'tracklength',2,@isnumeric);

addParameter(p,'linewidth',2,@isnumeric);


addParameter(p,'mark_blobs',false,@islogical);
addParameter(p,'bgcorrect',true,@islogical);
addParameter(p,'markblobs',false,@islogical);

addParameter(p,'report',100,@isnumeric);

addParameter(p,'outfile',[Trck.trackingdir,Trck.expname,'_ant_cropped.avi'],@ischar);

parse(p,Trck,id, fi, ff, varargin{:});

scale = Trck.get_param('geometry_rscale');

% load xy

if ~isempty(p.Results.m)
    ti = trtime(Trck,p.Results.m,fi);
    tf = trtime(Trck,p.Results.m,ff);
    fi = ti.f;
    ff = tf.f;
end

ti = trtime(Trck,fi);
tf = trtime(Trck,ff);
t0 = trtime(Trck,ti.m,1);
f0 = t0.f;

XY = Trck.loadxy('movlist',ti.m:tf.m);

[~,~,BGW] = Trck.get_bg(ti);

% open video file
vw = VideoWriter(p.Results.outfile);
vw.FrameRate = Trck.er.framerate*p.Results.speedup;
open(vw)

trl = Trck.er.framerate * p.Results.tracklength;

% loop over frames
fs = ti.f:tf.f;
cnt = 1;


for f=fs
    
    
    cnt = cnt+1;
    ix = f-f0+1;
    
    if ~mod(cnt-1,p.Results.report)
        report('I',['Processing frame ',num2str(cnt),'/',num2str(length(fs))]);
    end 
    
    xy = XY.(id)(ix,1:2)/scale;
    
    ix1 = max(ix-trl,1);
    ix2 = min(ix+trl,size(XY.(id),1));
    
    track = XY.(id)(ix1:ix2,1:2)/scale;
    track = reshape(track',1,[]);
    
    frame = Trck.read_frame(f);
    
    if p.Results.markblobs
        detect_blobs(Trck);
    end
    
    I = im2single(frame);
        
    if p.Results.bgcorrect
        %corrected = I - BGW + 1;
        corrected = 0.9*I./BGW;
        I = corrected;
    end
    
    I0 = I;

    % draw track
    if p.Results.track
        I = insertShape(I,'Line',track,'Color',[0.8,0.1,0.1],'LineWidth',p.Results.linewidth);
        I = imlincomb(0.5,I0,0.5,I);
    end
    
    % crop
    center = round(xy);
    x = center(1) - round(p.Results.size(2)/2);
    y = center(2) - round(p.Results.size(1)/2);
    w = p.Results.size(2);
    h = p.Results.size(1);
    
    x = max(x,1);
    y = max(y,1);
    
    x = min(x,size(I,2)-w);
    y = min(y,size(I,1)-h);
    
    I = imcrop(I,[x,y,w,h]);    
    I = clip(I,[0,1]);
    
    % write frame
     writeVideo(vw,I);
    
end
    
% close video file
close(vw)