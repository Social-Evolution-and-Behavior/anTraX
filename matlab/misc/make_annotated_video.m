function make_annotated_video(Trck, varargin)

p = inputParser;

colors = distinguishable_colors(Trck.NIDs,{'w','k','y'});

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addParameter(p,'fi',1);
addParameter(p,'ff',600);
addParameter(p,'ids','all');
addParameter(p,'colony','');
addParameter(p,'outline',true,@islogical);
addParameter(p,'speedup',1,@isnumeric);
addParameter(p,'colors',colors,@isnumeric);
addParameter(p,'downsample',1,@isnumeric);
addParameter(p,'linewidth',3,@isnumeric);
addParameter(p,'mark_blobs',false,@islogical);
addParameter(p,'tail',true,@islogical);
addParameter(p,'tail_length',5,@isnumeric);
addParameter(p,'mask',Trck.TrackingMask,@isnumeric);
addParameter(p,'bgcorrect',true,@islogical);
addParameter(p,'text','',@ischar);
addParameter(p,'crop',false,@islogical);
addParameter(p,'markblobs',false,@islogical);
addParameter(p,'xy_smooth_window',10,@isnumeric);
addParameter(p,'labelsize',24,@isnumeric);

addParameter(p,'outfile',[Trck.trackingdir,Trck.expname,'_annotated.avi'],@ischar);

parse(p,Trck,varargin{:});

xy_smooth_window = p.Results.xy_smooth_window;
scale = Trck.get_param('geometry_rscale');
colors = p.Results.colors;


% 
if Trck.get_params('geometry_multi_colony')
    
    if isempty(p.Results.colony)
        report('E', 'multi colony experiment, please provide colony argument')
        return
    end
    
    if isnumeric(p.Results.colony)
        colony = Trck.colony_labels{p.Results.colony};
    elseif ismember(p.Results.colony, Trck.colony_labels)
        colony = p.Results.colony;
    else
        report('E', 'Bad colony value')
        return
    end
    
end

% load xy
fi = p.Results.fi;
ff = p.Results.ff;
ti = trtime(Trck,fi);
tf = trtime(Trck,ff);
t0 = trtime(Trck,ti.m,1);
f0 = t0.f;
XY0 = Trck.loadxy('movlist',ti.m:tf.m);

if Trck.get_params('geometry_multi_colony')
    XY0 = XY0.(colony);
end

for i=1:Trck.NIDs
    id = Trck.usedIDs{i};
    XY.(id)=XY0.(id)(fi-f0+1:ff-f0+1,:);
    XY.(id)=movmean(XY0.(id),xy_smooth_window,1,'omitnan');
end

% mask
[~,~,BGW] = Trck.get_bg(ti);
msk = p.Results.mask;
msk3 = single(msk);

% open video file
vw = VideoWriter(p.Results.outfile);
vw.FrameRate = Trck.er.framerate*p.Results.speedup/p.Results.downsample;
open(vw)

z = 15*rand(Trck.NIDs,2) - 60;

if p.Results.crop
    
    % for demo movie
    w = size(BGW,2);
    h = size(BGW,1);
    wout = 2000;
    hout = 1500;

    bbox = squarebbox(Trck.TrackingMask(:,:,1)>0,10);
   
    BGW = imcrop(BGW,bbox);
    a = size(BGW,1);
    BGW = imresize(BGW, [1000,1000]);
    
    
    if ~isempty(msk3)
        msk3 = imcrop(msk3,bbox);
        msk3 = imresize(msk3, [1000,1000]);
    end
    
    scale = scale * a/1000;
    
    bbox2 = bbox * 1000/a;
    
else
    bbox = [0,0];
    bbox2 = [0,0];
end

outline = repmat(imdilate(msk3(:,:,1)>0,ones(10)) &  imerode(msk3(:,:,1),ones(2))==0,[1,1,3]);

% loop over frames
for f=ti.f:p.Results.downsample:tf.f
    
    ix = f-f0+1;
    
    tail={};
    clrs=[];
    
    for j=1:Trck.NIDs
        
        id = Trck.usedIDs{j};
        
        xy(j,:) = XY.(id)(ix,1:2)/scale - bbox2(1:2);
        i0 = max(1,ix-p.Results.tail_length*10-1);
        
        taili = XY.(id)(i0:ix,1:2)/scale - repmat(bbox2(1:2),[ix-i0+1,1]);
        ok = ~isnan(taili(:,1));
        [sqlen,~,sqstart,sqend] = divide2seq(ok,true);
        for k=1:length(sqstart)
            if sqlen(k)<2
                continue
            end
           tailk=taili(sqstart(k):sqend(k),:); 
           tail{end+1} = reshape(tailk',1,[]);
           clrs(end+1,:) = colors(j,:);
        end
        
        %loc(j,:) = round(xy(j,:)/scale) + 25*[sin(2*pi*j/Trck.NIDs),cos(2*pi*j/Trck.NIDs)];
       
    end
    
    loc = round(xy) + z;
    ok = ~isnan(xy(:,1));
   
    frame = Trck.read_frame(f);
    if p.Results.markblobs
        detect_blobs(Trck);
    end
    I = im2single(frame);
    
    if p.Results.crop
        I = imcrop(I,bbox);
        I = imresize(I, [1000,1000]);
    end
    
    if p.Results.bgcorrect
        
        I = I - BGW + 1;
        %I = 0.9*I./BGW;
        
    end
    
    I0 = I;
    
    
    % draw tails
    if f>fi && ~isempty(tail)
        I = insertShape(I,'Line',tail,'Color',clrs,'LineWidth',p.Results.linewidth);
    end
    
    I = imlincomb(0.5,I0,0.5,I);
    
    if ~isempty(p.Results.mask)
        I = msk3.*I + (1-msk3);
    end
    
    if ~isempty(p.Results.mask) && p.Results.bgcorrect && p.Results.outline
        I(outline) = 0.3;
    end
    
    % insert labels
    if any(ok)
        I = insertText(I,loc(ok,:),Trck.usedIDs(ok),'FontSize',p.Results.labelsize,'BoxColor',colors(ok,:),'BoxOpacity',0.5,'TextColor','white');
    end
    
    % text
    switch p.Results.text
        
        case 'frame'
            txt = num2str(f);
            I = insertText(I,[20,20],txt,'FontSize',24,'BoxColor',...
        'white','BoxOpacity',0.4,'TextColor',[0.1,0.7,0.2]);

        
    end
    
    %I = imcrop(I,2*rect);
    I = clip(I,[0,1]);
    
    % write frame
     writeVideo(vw,I);
    
end
    
% close video file
close(vw)