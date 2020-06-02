function make_masked_video(Trck, varargin)

p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addParameter(p,'fi',1);
addParameter(p,'ff',600);
addParameter(p,'ids','all');
addParameter(p,'colony','');
addParameter(p,'outline',true,@islogical);
addParameter(p,'objectmask',[],@isnumeric);
addParameter(p,'coloredobject',[],@isnumeric);
addParameter(p,'speedup',1,@isnumeric);
addParameter(p,'markblobs',false,@islogical);
addParameter(p,'downsample',1,@isnumeric);
addParameter(p,'mask',true,@(x) isnumeric(x) || islogical(x));
addParameter(p,'bgcorrect',true,@islogical);
addParameter(p,'bgcorrect_mask',[],@isnumeric);
addParameter(p,'enhance_factor',1,@isnumeric);
addParameter(p,'text','',@ischar);
addParameter(p,'crop',false,@islogical);
addParameter(p,'size',[1000,1000],@isnumeric);
addParameter(p,'f0',0,@isnumeric);
addParameter(p,'flip',[],@isnumeric);
addParameter(p,'report',100,@isnumeric);
addParameter(p,'foodobject',[]);

addParameter(p,'outfile',[Trck.trackingdir,Trck.expname,'_annotated.avi'],@ischar);

parse(p,Trck,varargin{:});

scale = Trck.get_param('geometry_rscale');

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

t0 = trtime(Trck,ti.m,1);
f0 = t0.f;

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
else
    bgcorrect_mask = double(p.Results.bgcorrect_mask>0);
end


% open video file
vw = VideoWriter(p.Results.outfile);
vw.FrameRate = Trck.er.framerate*p.Results.speedup/p.Results.downsample;
open(vw)

if p.Results.crop
    
    % for demo movie
    w = size(BGW,2);
    h = size(BGW,1);
    wout = 2000;
    hout = 1500;
    
    bbox = squarebbox(msk(:,:,1)>0,10);

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
object = p.Results.objectmask>0;

if ~isempty(object) && size(object,3)==1
    object = repmat(object,[1,1,3])>0;
end

cobject = p.Results.coloredobject;

if ~isempty(cobject) && size(cobject,3)==1
    cobject = repmat(cobject,[1,1,3]);
end

% loop over frames
fs = ti.f:p.Results.downsample:tf.f;
cnt = 1;
for f=fs
    
    
    cnt = cnt+1;
    
    if ~mod(cnt-1,p.Results.report)
        report('I',['Processing frame ',num2str(cnt),'/',num2str(length(fs))]);
    end
    
   
    frame = Trck.read_frame(f);
    
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
        
        
        corrected = I - BGW + 1;
        %corrected = 0.9*I./BGW;
        %corrected = imadjust(corrected,[min(corrected(:)),1]);
        corrected = p.Results.enhance_factor*corrected-p.Results.enhance_factor/2;
        corrected = clip(corrected,[0,1]);
        
        %corrected(corrected>0.73) = 0.73;
        
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
    
    
    I = imlincomb(0.5,I0,0.5,I);
    
    if ~isempty(object)
        I(object) = 0.3;
    end
    
    if ~isempty(cobject)
        I(cobject>0) = cobject(cobject>0);
    end
    
    if p.Results.mask
        I = msk3.*I + (1-msk3);
    end
    
    if ~isempty(p.Results.mask) && p.Results.bgcorrect && p.Results.outline
        I(outline) = 0.3;
    end
   
    if ~isempty(p.Results.flip)
        I = flipm(I,p.Results.flip);
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
    
    % food annotation
    if ~isempty(p.Results.foodobject)
        
        food = p.Results.foodobject;
        
        if ~isempty(p.Results.flip)
            if ismember(1,p.Results.flip)
                food.y = size(I,1)-food.y+1;
            end
            if ismember(2,p.Results.flip)
                food.x = size(I,2)-food.x+1;
            end
        end

        
        if f >= food.fi && f <= food.ff
 
            I = insertShape(I,'Circle',[food.x, food.y, food.radius],...
                'Color',food.color,...
                'LineWidth',food.linewidth);
           
            I = insertText(I,[food.x,food.y]+food.offset,food.text,...
                'FontSize', food.fontsize,...
                'BoxColor', 'red',...
                'BoxOpacity',0,...
                'TextColor',food.color);
            
        end
    end
    
    
    %I = imcrop(I,2*rect);
    I = clip(I,[0,1]);
        
    % write frame
     writeVideo(vw,I);
    
end
    
% close video file
close(vw)