function make_annotated_video(Trck, varargin)

p = inputParser;


Trck = trhandles.load(Trck);
colors = distinguishable_colors(Trck.NIDs,{'w'});

addRequired(p,'Trck',@(x) (ischar(x) && isfolder(x)) || isa(x,'trhandles'));
addParameter(p,'fi',1);
addParameter(p,'ff',600);
addParameter(p,'annotate_tracks',true);
addParameter(p,'ids','all');
addParameter(p,'colony','');
addParameter(p,'outline',true,@islogical);
addParameter(p,'speedup',1,@isnumeric);
addParameter(p,'colors',colors,@isnumeric);
addParameter(p,'downsample',1,@isnumeric);
addParameter(p,'linewidth',3,@isnumeric);
addParameter(p,'mark_blobs',false,@islogical);
addParameter(p,'tail',true,@islogical);
addParameter(p,'interpolate_maxd',0.003,@isnumeric);
addParameter(p,'interpolate_maxf',10,@isnumeric);
addParameter(p,'tail_length',5,@isnumeric);
addParameter(p,'mask',true,@(x) isnumeric(x) || islogical(x));
addParameter(p,'bgcorrect',true,@islogical);
addParameter(p,'bgcorrect_mask',[]);
addParameter(p,'text','',@ischar);
addParameter(p,'crop',false,@islogical);
addParameter(p,'size',[1000,1000],@isnumeric);
addParameter(p,'markblobs',false,@islogical);
addParameter(p,'xy_smooth_window',0,@isnumeric);
addParameter(p,'labelsize',24,@isnumeric);
addParameter(p,'labeloffset',24,@isnumeric);
addParameter(p,'f0',-1,@isnumeric);
addParameter(p,'flip',[],@isnumeric);
addParameter(p,'report',100,@isnumeric);
addParameter(p,'enhance_factor',1,@isnumeric);
addParameter(p,'enhance_bias',0,@isnumeric);
addParameter(p,'outfile',[Trck.trackingdir,Trck.expname,'_annotated.avi'],@ischar);
parse(p,Trck,varargin{:});




xy_smooth_window = p.Results.xy_smooth_window;
scale = Trck.get_param('geometry_rscale');
colors = p.Results.colors;
% 
if Trck.get_param('geometry_multi_colony')
    
    if isempty(p.Results.colony)
        report('E', 'multi colony experiment, please provide colony argument')
        return
    end
    
    if isnumeric(p.Results.colony)
        cix = p.Results.colony;
        colony = Trck.colony_labels{cix};
    elseif ismember(p.Results.colony, Trck.colony_labels)
        colony = p.Results.colony;
        cix = find(strcmp(p.Results.colony,Trck.colony_labels));
    else
        report('E', 'Bad colony value')
        return
    end
    
end

% load xy
fi = p.Results.fi;
ff = p.Results.ff;
if isa(fi,'trtime')
    ti = fi;
    tf = ff;
else
    ti = trtime(Trck,fi);
    tf = trtime(Trck,ff);
end

fi = ti.f;
ff = tf.f;

if p.Results.f0<0
    t0 = trtime(Trck,ti.m,1);
    f0 = t0.f;
else
    f0 = p.Results.f0;
    t0 = trtime(Trck,f0);
end

if p.Results.annotate_tracks

XY0 = Trck.loadxy('movlist',t0.m:tf.m);

end

if Trck.get_param('geometry_multi_colony')
    XY0 = XY0.(colony);
end

if p.Results.annotate_tracks

for i=1:Trck.NIDs
    id = Trck.usedIDs{i};
    xy1 = XY0.(id)(fi-f0+1:ff-f0+1,:);
    
    % interpolate
    xy2 = filter_jumps(xy1,0.01);
    xy3 = interpolate_xy(xy2, p.Results.interpolate_maxd, p.Results.interpolate_maxf);
    XY.(id) = xy3;
    
    % smooth
    if p.Results.xy_smooth_window > 0
        xy4 = movmean(xy3,xy_smooth_window,1);
        nanmask = isnan(xy4(:,1));
        xy4(nanmask,1:2) = xy3(nanmask,1:2);
        XY.(id) = xy4;
    end
    
end
end


% mask
[~,~,BGW] = Trck.get_bg(ti);

if isfield(Trck.Masks,'video')
    msk = Trck.Masks.video;
elseif Trck.get_param('geometry_multi_colony')
    error('need to be implemented')
else
    msk = Trck.Masks.roi;
end

msk3 = single(msk);


if isempty(p.Results.bgcorrect_mask)
    bgcorrect_mask = ones(size(msk3));
elseif ischar(p.Results.bgcorrect_mask)
    bgcorrect_mask = double(Trck.Masks.(p.Results.bgcorrect_mask))>0;
else
    bgcorrect_mask = double(p.Results.bgcorrect_mask>0);
end


% open video file
outfile = p.Results.outfile;
transcode = false;

if strcmp(outfile(end-2:end), 'mp4')
    outfile(end-2:end) = 'avi';
    transcode = true;
end

disp(outfile)
vw = VideoWriter(outfile);
framerate = double(Trck.er.framerate*p.Results.speedup/p.Results.downsample);
vw.FrameRate = framerate;
report('I', ['Framerate is ', num2str(framerate), ' class ', class(framerate)])
open(vw)

if p.Results.annotate_tracks

    z = p.Results.labeloffset*rand(Trck.NIDs,2)/2 - repmat([-p.Results.labeloffset,p.Results.labeloffset],Trck.NIDs,1);

end


if p.Results.crop
    
    % for demo movie
    w = size(BGW,2);
    h = size(BGW,1);
    wout = 2000;
    hout = 1500;
    
    bbox = squarebbox(msk(:,:,1)>0,25);

    BGW = imcrop(BGW,bbox);
    a = size(BGW,1);
    BGW = imresize(BGW, p.Results.size);
    
    bgcorrect_mask = imcrop(bgcorrect_mask,bbox);
    bgcorrect_mask = imresize(bgcorrect_mask, p.Results.size);
    
    if ~isempty(msk3)
        msk3 = imcrop(msk3,bbox);
        msk3 = imresize(msk3, p.Results.size);
    end
    
    scale = scale * a/p.Results.size(1);
    
    bbox2 = bbox * p.Results.size(1)/a;
    
else
    bbox = [0,0];
    bbox2 = [0,0];
end

outline = repmat(imdilate(msk3(:,:,1)>0,strel('disk',10)) &  imerode(msk3(:,:,1),ones(2))==0,[1,1,3]);

% loop over frames
fs = ti.f:p.Results.downsample:tf.f;
cnt = 1;
for f=fs
    
    
    cnt = cnt+1;
    ix = f-fi+1;
    
    if ~mod(cnt-1,p.Results.report)
        report('I',['Processing frame ',num2str(cnt),'/',num2str(length(fs))]);
    end
    
    tail=[];
    clrs=[];
    
    if p.Results.annotate_tracks

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
           tailk = taili(sqstart(k):sqend(k),:); 
           tailk = [tailk(1:end-1,:),tailk(2:end,:)];          
           tail = cat(1,tail,tailk);
           clrs(end+1:end+size(tailk,1),:) = repmat(colors(j,:),[size(tailk,1),1]);
           %tail{end+1} = round(reshape(tailk',1,[]));
           %clrs(end+1,:) = colors(j,:);
        end
        
        %loc(j,:) = round(xy(j,:)/scale) + 25*[sin(2*pi*j/Trck.NIDs),cos(2*pi*j/Trck.NIDs)];
       
    end
    
    loc = round(xy) + z;
    ok = ~isnan(xy(:,1));
   
    end
    
    frame = Trck.read_frame(f);
    
    if isempty(frame)
        report('E', 'Corrupt frame')
        continue
    end
    
    
    if p.Results.markblobs 
        detect_blobs(Trck);
        ab = Trck.currfrm.antblob;
        S = regionprops(ab.LABEL,Trck.currfrm.grayIm,'ConvexHull');
    end
    
    I = im2single(frame);
    
    if p.Results.crop
        I = imcrop(I,bbox);
        I = imresize(I, p.Results.size);
    end
    
    if p.Results.bgcorrect
        
        %corrected = 0.9*I./BGW;
        corrected = I - BGW + 1;
        %corrected = 1.7*corrected-0.55;
        corrected = p.Results.enhance_factor*corrected-(p.Results.enhance_factor-1)/2;
        corrected = 0.9*corrected;
        corrected = corrected+p.Results.enhance_bias;
        corrected = clip(corrected,[0,1]);
        I = corrected.*bgcorrect_mask + I.*(1-bgcorrect_mask);
                
    end
    
    I0 = I;
    
    if p.Results.markblobs
        ch = {};
        for i=1:length(S)
            ch{i} = reshape(S(i).ConvexHull',1,[]);
        end
        
        I = insertShape(I,'Polygon',ch,'Color',[0.8,0.22,0.5],'LineWidth',4);
    end
    
    
    % draw tails
    if p.Results.annotate_tracks

    if f>fi && ~isempty(tail)
        I = insertShape(I,'Line',tail,'Color',clrs,'LineWidth',p.Results.linewidth,'SmoothEdges',true);
    end
    end
    
    I = imlincomb(0.5,I0,0.5,I);
    
    if p.Results.mask
        I = msk3.*I + (1-msk3);
    end
    
    if ~isempty(p.Results.mask) && p.Results.bgcorrect && p.Results.outline
        I(outline) = 0.3;
    end
    
    
    if ~isempty(p.Results.flip)
        
        I = flipm(I,p.Results.flip);
        
        if ismember(1,p.Results.flip)
           loc(:,2) = size(I,1) - loc(:,2) + 1; 
        end
        
        if ismember(2,p.Results.flip)
           loc(:,1) = size(I,2) - loc(:,1) + 1; 
        end
        
    end
    
    % insert labels
    if p.Results.annotate_tracks
    if any(ok)
        I = insertText(I,loc(ok,:),Trck.usedIDs(ok),'FontSize',p.Results.labelsize,'BoxColor',colors(ok,:),'BoxOpacity',0.5,'TextColor','white');
    end
    end
    
    % text
    switch p.Results.text
        
        
        
        case 'frame'
            txtloc =  [20,size(I,1)-100];
            fontsize = 128 * p.Results.size(1)/1000;
            txt = num2str(f-f0);
            
            I = insertText(I,txtloc,txt,'FontSize',fontsize,'BoxColor',...
        'white','BoxOpacity',0.4,'TextColor',[0.1,0.7,0.2]);

        case 'time'
            txtloc =  [20,size(I,1)-200*p.Results.size(1)/1000];
            fontsize = 100 * p.Results.size(1)/1000;
            
            day = (f-f0)/Trck.er.fps/24/3600;
            txt = datestr(day,13);
            
            I = insertText(I,txtloc,txt,'FontSize',fontsize,'BoxColor',...
        'white','BoxOpacity',0.4,'TextColor',[0.1,0.7,0.2]);
            
            
    end
    
    %I = imcrop(I,2*rect);
    I = clip(I,[0,1]);
    
    
    % write frame
    try
        writeVideo(vw,I);
    catch
        report('E', 'Corrupt frame')
    end
    
end
    
% close video file
close(vw)


% if ext is mp4, transcode video
if transcode
    infile = outfile;
    outfile = [infile(1:end-3), 'mp4'];
    if exist(outfile, 'file') && ~strcmp(infile, outfile)
        delete(outfile)
    end
    system(['ffmpeg -i "',infile,'" -c:v libx264 -preset fast -crf 30 -c:a copy "',outfile,'"']); 
    delete(infile);
end




