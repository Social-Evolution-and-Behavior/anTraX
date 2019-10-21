function ims = get_image_from_vid(trj,tt)

ix = trj.time2indx(tt);
bbox = trj.BBOX(ix,:);
wh = single(max(max(bbox(:,3:4))));
wh = ceil(wh/2);
cent = single(round(trj.CENTROID(ix,:)));
bbox = [cent - repmat(wh,size(cent,1),1),2*repmat(wh,size(cent,1),2)];

for i=1:length(tt)
    frame = trj.Trck.er.read(tt(i));
    ims(:,:,:,i) = imcrop(frame,bbox(i,:));
end