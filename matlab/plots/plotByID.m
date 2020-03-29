function fh=plotByID(Trck,XY,fh,shape,annotate)

if nargin<3
    fh=figure;
end


[ax,idorder] = prepare_colony_axes(Trck,fh,shape,annotate);

scale = Trck.get_param('geometry_rscale');

msk = Trck.TrackingMask(:,:,1)>0;
%marker = false(size(msk));
%marker(round(trjs(1).CY(1)),round(trjs(1).CX(1)))=true;
%msk = imreconstruct(marker,msk);
stats = regionprops(msk,'BoundingBox','ConvexImage','Centroid');

bb = stats.BoundingBox;

for i=1:numel(idorder)
    ID = idorder{i};
    axes(ax(i))
    hold on
    xy = filter_jumps(XY.(ID),0.01)/scale;
    xy(:,1) = smooth(xy(:,1),19);
    xy(:,2) = smooth(xy(:,2),19);
    plot(xy(:,1),-xy(:,2),'LineWidth',0.5,'Color',[0.3,0.3,0.3,0.5]);
    axis([bb(1),bb(1)+bb(3),-bb(2)-bb(4),-bb(2)]);
    axis off
end


        



