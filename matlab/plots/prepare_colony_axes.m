function [ax,idorder] = prepare_colony_axes(Trck,fh)

figure(fh)
set(fh,'Position',[1,1,800,800])
clf

NC = length(Trck.tagcolors);
axis_x = 0.05:0.9/NC:1;
axis_y = 0.05:0.9/NC:1;

axis_w = 0.95 * 0.9/NC;
axis_h = 0.95 * 0.9/NC;

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
idorder=cell(1,16);
cnt=1;
for i=1:NC
    for j=1:NC
        ax(cnt) = subplot('Position',[axis_x(j),axis_y(i),axis_w,axis_h]);
        idorder{cnt}=[tagcolors{NC-i+1},tagcolors{j}];
        annotation('ellipse',[tag1x(j),tag1y(i),tagsize,tagsize],'Color','none','FaceColor',tagrgb(NC-i+1,:))
        annotation('ellipse',[tag2x(j),tag2y(i),tagsize,tagsize],'Color','none','FaceColor',tagrgb(j,:))
        cnt = cnt+1;
    end
end
