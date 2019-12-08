function ims = mm_align(ims, params)

sz = size(ims);

for k=1:size(ims,4)
    
    im = ims(:,:,:,k);
    
    bw = bwareafilt(im>0.45,1);
    S = regionprops(bw,'Orientation','Centroid');
    
    im = padarray(im,[sz(1)/2,sz(1)/2,0]);
    im = imcrop(im,[S.Centroid(1),S.Centroid(2),sz(1)-1,sz(1)-1]);
    im = imrotate(im,90-S.Orientation,'crop');
    
    % center of mass
    bw = bwareafilt(im>0.4,1);
    S = regionprops(bw,imopen(im,ones(5))>0.45,'WeightedCentroid','Extrema');
    y1 = S.WeightedCentroid(2)+0.5;
    y2 = mean([max(S.Extrema(:,2)),min(S.Extrema(:,2))]);
    
    if  y1 - y2 > 3
        
        im = flipm(im,[1,2]);
        
    elseif y1 - y2 > -3
        
        d = imtophat(imclose(im>0.45,ones(5)),ones(5));
        [~,Y] = meshgrid(1:sz(1),1:sz(2));
        cy = sum(Y(:) .* d(:))/sum(d(:));
        if cy < sz(1)/2 - 2
            im = flipm(im,[1,2]);
        end
        
    end
    
    ims(:,:,:,k) = im;
    
end