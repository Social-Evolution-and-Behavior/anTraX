function make_annotated_video(Trck, varargin)

p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addParameter(p,'fi',1);
addParameter(p,'ff',600);
addParameter(p,'ids','all');
addParameter(p,'speedup',1,@isnumeric);
addParameter(p,'downsample',1,@isnumeric);
addParameter(p,'mark_blobs',false,@islogical);
addParameter(p,'tail',true,@islogical);
addParameter(p,'tail_length',20,@isnumeric);
addParameter(p,'mask',Trck.tracking_mask,@isnumeric);
addParameter(p,'bgcorrect',true,@islogical);
addParameter(p,'outfile',[Trck.sessiondir,'annotated.avi'],@ischar);

parse(p,Trck,varargin{:});

xy_smooth_window = 10;
scale = Trck.get_param('geometry_rscale');
colors = distinguishable_colors(Trck.NIDs);

% load xy
fi = p.Results.fi;
ff = p.Results.ff;
ti = trtime(Trck,fi);
tf = trtime(Trck,ff);
t0 = trtime(Trck,ti.m,1);
f0 = t0.f;
XY0 = Trck.loadxy(ti.m:tf.m);

for i=1:Trck.NIDs
    id = Trck.usedIDs{i};
    XY.(id)=XY0.(id)(fi-f0+1:ff-f0+1,:);
    XY.(id)=movmean(XY0.(id),xy_smooth_window,1,'omitnan');
end

% mask
[~,~,BGW] = Trck.get_bg(ti);
msk = p.Results.mask;
msk3 = repmat(msk,[1,1,3]);

% open video file
vw = VideoWriter(p.Results.outfile);
vw.FrameRate = Trck.er.framerate*p.Results.speedup/p.Results.downsample;
open(vw)


% loop over frames
for f=ti.f:p.Results.downsample:tf.f
    
    
    tail={};
    clrs=[];
    
    for j=1:Trck.NIDs
        
        id = Trck.usedIDs{j};
        
        xy(j,:) = XY.(id)(i,1:2);
        i0 = max(1,i-tail_length*10-1);
        
        taili = XY.(id)(i0:i,1:2)/scale;
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
       
    end
    
    loc = round(xy/scale) + repmat([20,-50],[Trck.NIDs,1]);
    ok=~isnan(xy(:,1));
    
    
    frame = Trck.er.read(f);
    I = im2single(frame);
    
    if p.Results.bgcorrect
        I = 0.9*I./BGW;
    end
        
    if ~isempty(p.Results.mask)
        I = I.*msk3 + I.*(~msk3);
    end
    
    I0 = I;
    
    % draw tails
    if f>fi
        I = insertShape(I,'Line',tail,'Color',clrs,'LineWidth',3);
    end
    
    I = imlincomb(0.5,I0,0.5,I);
    
    % insert labels
    I = insertText(I,2*loc(ok,:),Trck.usedIDs(ok),'FontSize',36,'BoxColor',colors(ok,:),'BoxOpacity',0.5,'TextColor','white');
    I = msk.*I + (1-msk);
    I = imcrop(I,2*rect);
    I = clip(I,[0,1]);
    
    % write frame
     writeVideo(vw,I);
    
end
    
% close video file
close(vw)