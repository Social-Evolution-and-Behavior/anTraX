function make_annotated_video_multi_colony(Trck, varargin)

p = inputParser;

colors = distinguishable_colors(Trck.NIDs,{'w','y'});

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addParameter(p,'fi',1);
addParameter(p,'ff',600);
addParameter(p,'ids','all');
addParameter(p,'outline',true,@islogical);
addParameter(p,'speedup',1,@isnumeric);
addParameter(p,'colors',colors,@isnumeric);
addParameter(p,'downsample',1,@isnumeric);
addParameter(p,'linewidth',3,@isnumeric);
addParameter(p,'mark_blobs',false,@islogical);
addParameter(p,'tail',true,@islogical);
addParameter(p,'tail_length',5,@isnumeric);
addParameter(p,'mask',true,@(x) islogical(x) || isnumeric(x));
addParameter(p,'bgcorrect',true,@islogical);
addParameter(p,'bgcorrect_mask',[],@isnumeric);
addParameter(p,'text','',@ischar);
addParameter(p,'crop',false,@islogical);
addParameter(p,'size',[1000,1000],@isnumeric);
addParameter(p,'markblobs',false,@islogical);
addParameter(p,'xy_smooth_window',10,@isnumeric);
addParameter(p,'labelsize',24,@isnumeric);
addParameter(p,'labeloffset',24,@isnumeric);
addParameter(p,'f0',0,@isnumeric);
addParameter(p,'report',100,@isnumeric);

addParameter(p,'outfile',[Trck.trackingdir,Trck.expname,'_annotated.avi'],@ischar);

parse(p,Trck,varargin{:});

xy_smooth_window = p.Results.xy_smooth_window;
scale = Trck.get_param('geometry_rscale');
colors = p.Results.colors;


% 
if ~Trck.get_param('geometry_multi_colony')
    report('E', 'not multi colony experiment, abborting')
end
    

% load xy
fi = p.Results.fi;
ff = p.Results.ff;
ti = trtime(Trck,fi);
tf = trtime(Trck,ff);
t0 = trtime(Trck,ti.m,1);
f0 = t0.f;

XY0 = Trck.loadxy('movlist',ti.m:tf.m);

colony_labels = fieldnames(XY0);
ncolonies = length(colony_labels);

for c=1:ncolonies
    cl = colony_labels{c};
    for i=1:Trck.NIDs
        id = Trck.usedIDs{i};
        XY.(cl).(id) = XY0.(cl).(id)(fi-f0+1:ff-f0+1,:);
        if p.Results.xy_smooth_window>0
            XY.(cl).(id) = movmean(XY0.(cl).(id),xy_smooth_window,1,'omitnan');
        end
    end
end


% mask
[~,~,BGW] = Trck.get_bg(ti);

if isfield(Trck.Masks,'video')
    msk = Trck.Masks.video;
else
    msk = Trck.Masks.roi;
end

msk3 = single(msk);

if isempty(p.Results.bgcorrect_mask)
    bgcorrect_mask = ones(size(msk3));
else
    bgcorrect_mask = double(p.Results.bgcorrect_mask>0);
end


% open video file
vw = VideoWriter(p.Results.outfile);
vw.FrameRate = Trck.er.framerate*p.Results.speedup/p.Results.downsample;
open(vw)

z = p.Results.labeloffset*rand(Trck.NIDs,2)/2 - repmat([-p.Results.labeloffset,p.Results.labeloffset],Trck.NIDs,1);
z = shiftdim(z,-1);


if p.Results.crop
    report('E','Crop with multi colony not implemented')
end
    

bbox = [0,0];
bbox2 = [0,0];

outline = repmat(imdilate(msk3(:,:,1)>0,ones(10)) &  imerode(msk3(:,:,1),ones(2))==0,[1,1,3]);

% loop over frames
fs = ti.f:p.Results.downsample:tf.f;
cnt = 1;

for f=fs
    
    
    cnt = cnt+1;
    ix = f-f0+1;
    
    if ~mod(cnt-1,p.Results.report)
        report('I',['Processing frame ',num2str(cnt),'/',num2str(length(fs))]);
    end
    
    tail={};
    clrs=[];
    
    for c=1:ncolonies
        cl = colony_labels{c};
        for j=1:Trck.NIDs
            
            id = Trck.usedIDs{j};
            
            xy(c,j,:) = XY.(cl).(id)(ix,1:2)/scale - bbox2(1:2);
            i0 = max(1,ix-p.Results.tail_length*10-1);
            
            taili = XY.(cl).(id)(i0:ix,1:2)/scale - repmat(bbox2(1:2),[ix-i0+1,1]);
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
    end
    
    loc = round(xy) + z;
    ok = ~isnan(xy(:,:,1));
   
    frame = Trck.read_frame(f);
    if p.Results.markblobs
        detect_blobs(Trck);
    end
    I = im2single(frame);
    
    if p.Results.crop
        I = imcrop(I,bbox);
        I = imresize(I, p.Results.size);
    end
    
    if p.Results.bgcorrect
            
        %corrected = I - BGW + 1;
        corrected = 0.9*I./BGW;
        
        I = corrected.*bgcorrect_mask + I.*(1-bgcorrect_mask);
           
    end
    
    I0 = I;
    
    % draw tails
    if f>fi && ~isempty(tail)
        I = insertShape(I,'Line',tail,'Color',clrs,'LineWidth',p.Results.linewidth);
    end
    
    I = imlincomb(0.5,I0,0.5,I);
    
    if p.Results.mask
        I = msk3.*I + (1-msk3);
    end
    
    if ~isempty(p.Results.mask) && p.Results.bgcorrect && p.Results.outline
        I(outline) = 0.3;
    end
    
    % insert labels
    for c=1:ncolonies
        okc = squeeze(ok(c,:));
        locc = squeeze(loc(c,:,:));
        if any(ok)
            I = insertText(I,locc(okc,:),Trck.usedIDs(okc),'FontSize',p.Results.labelsize,'BoxColor',colors(okc,:),'BoxOpacity',0.5,'TextColor','white');
        end
    end
    
    % text
    switch p.Results.text

        case 'frame'
            txtloc =  [20,size(I,1)-100];
            fontsize = 48 * p.Results.size(1)/1000;
            txt = num2str(f-f0);
            
            I = insertText(I,txtloc,txt,'FontSize',fontsize,'BoxColor',...
        'white','BoxOpacity',0.4,'TextColor',[0.1,0.7,0.2]);

        case 'time'
            txtloc =  [20,size(I,1)-100*p.Results.size(1)/1000];
            fontsize = 48 * p.Results.size(1)/1000;
            
            day = (f-f0)/Trck.er.fps/24/3600;
            txt = datestr(day,13);
            
            I = insertText(I,txtloc,txt,'FontSize',fontsize,'BoxColor',...
        'white','BoxOpacity',0.4,'TextColor',[0.1,0.7,0.2]);
            
            
    end
    
    %I = imcrop(I,2*rect);
    I = clip(I,[0,1]);
    
    % write frame
     writeVideo(vw,I);
    
end
    
% close video file
close(vw)