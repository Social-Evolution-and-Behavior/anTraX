function [ax,idorder] = prepare_colony_axes(Trck,fh, shape, annotate)

figure(fh)
set(fh,'Position',[1,1,800,800])
clf

if nargin<4
    annotate = True;
end


NC = numel(Trck.labels.tagcolors);

if nargin<3 || isempty(shape)
    
    NC = length(Trck.tagcolors);
    shape = [NC,NC];
    
end


axis_x = 0.05:0.9/shape(1):0.949;
axis_y = 0.05:0.9/shape(2):0.949;

axis_x = repmat(axis_x,[1,shape(2)]);
axis_y = repmat(axis_y,[shape(1),1]);
axis_y = axis_y(:);
axis_y = axis_y(end:-1:1);

axis_w = 0.95 * 0.9/shape(1);
axis_h = 0.95 * 0.9/shape(2);


if annotate
    
    tagsize = 0.015;
    
    tag1x = axis_x;
    tag1y = axis_y + axis_h - tagsize;
    tag2x = axis_x;
    tag2y = axis_y + axis_h - 2*tagsize;
    
    
    tagcolors = Trck.tagcolors;
    
    B = [24,116,240]/255;
    G = [0,128,0]/255;
    O = [250,153,18]/255;
    P = [238,18,137]/255;
    L = [145,44,238]/255;
    Y = [255,255,0]/255;
    
    for i=1:NC
        tagrgb(i,:) = eval(tagcolors{i});
    end
    
end

idorder=cell(1,Trck.NIDs);
for i=1:Trck.NIDs
    
    ii = ceil(i/NC);
    jj = rem(i,NC)+1;
    
    ax(i) = subplot('Position',[axis_x(i),axis_y(i),axis_w,axis_h]);
    
    idorder{i}=Trck.usedIDs{i};
    
    if annotate
        annotation('ellipse',[tag1x(i),tag1y(i),tagsize,tagsize],'Color','none','FaceColor',tagrgb(ii,:))
        annotation('ellipse',[tag2x(i),tag2y(i),tagsize,tagsize],'Color','none','FaceColor',tagrgb(jj,:))
    end
end
