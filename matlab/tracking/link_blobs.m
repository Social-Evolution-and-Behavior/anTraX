function link_blobs(Trck)

% initialize connection matrices
Trck.ConnectArray=zeros(Trck.prevfrm.antblob.Nblob,Trck.currfrm.antblob.Nblob);
Trck.ConnectArraybin=zeros(Trck.prevfrm.antblob.Nblob,Trck.currfrm.antblob.Nblob,'logical');

% if no blob present in current or previous frame, skip
if Trck.currfrm.antblob.Nblob==0 || Trck.prevfrm.antblob.Nblob==0
    return
end

% get dilating kernel

dt = Trck.currfrm.dat.tracking_dt;
dt = min([dt, 4/Trck.er.framerate]);
dt = max([dt, 1/Trck.er.framerate]);
dilatespeed = Trck.get_param('linking_maxspeed') * Trck.get_param('linking_cluster_radius_coeff');
dilaterad = dilatespeed*dt/Trck.get_param('geometry_rscale');
dilatepropag = strel('disk',ceil(dilaterad),0);

% dilate prev and current frames
combined0 = imdilate(Trck.prevfrm.BW_2|Trck.currfrm.BW_2,dilatepropag);
combined = bwconvhull(combined0,'objects');
combined = combined & Trck.Masks.roi(:,:,1);

%combined = applyMasktoIm(combined,Trck.Masks.roi);
Trck.currfrm.LinkingClusters = combined; 

% partition to clusters
cluster_label = bwlabel(combined);
cluster_stats = regionprops(combined>0,'BoundingBox','Image');
blobclusterprev = cluster_label(sub2ind(size(cluster_label),round(Trck.prevfrm.antblob.DATA.CENTROID(:,2)),round(Trck.prevfrm.antblob.DATA.CENTROID(:,1))));
blobclustercurr = cluster_label(sub2ind(size(cluster_label),round(Trck.currfrm.antblob.DATA.CENTROID(:,2)),round(Trck.currfrm.antblob.DATA.CENTROID(:,1))));

Trck.currfrm.cluster_nblobs_prev = [];
Trck.currfrm.cluster_nblobs_curr = [];

for i=1:max(cluster_label(:))
    
    previx = find(blobclusterprev==i);
    currix = find(blobclustercurr==i);
    
    Trck.currfrm.cluster_nblobs_prev(i) = numel(previx);
    Trck.currfrm.cluster_nblobs_curr(i) = numel(currix);
    
    % if the cluster contains exactly one blob in each frame, link
    if numel(previx)==1 && numel(currix)==1 
        Trck.ConnectArraybin(previx,currix)=true;
    % else run optical flow in the cluster for connections
    else
        
        if isempty(Trck.prevfrm.filteredGrayIm)
            Trck.prevfrm.filteredGrayIm = imfilter(Trck.prevfrm.grayIm,Trck.get_param('linking_offilter'));
        end
        
        if isempty(Trck.currfrm.filteredGrayIm)
            Trck.currfrm.filteredGrayIm = imfilter(Trck.currfrm.grayIm,Trck.get_param('linking_offilter'));
        end
        
        
        
        bb = cluster_stats(i).BoundingBox;
        bb(1:2)=round(bb(1:2));
        bb(3:4)=bb(3:4)-1;
        msk = cluster_stats(i).Image;
        imprev = applyMasktoIm(Trck.prevfrm.filteredGrayIm(bb(2):bb(2)+bb(4),bb(1):bb(1)+bb(3)),msk);
        imcurr = applyMasktoIm(Trck.currfrm.filteredGrayIm(bb(2):bb(2)+bb(4),bb(1):bb(1)+bb(3)),msk);
        reset(Trck.opticalFlow);
        estimateFlow(Trck.opticalFlow,imprev);
        of = estimateFlow(Trck.opticalFlow,imcurr);
        
        % find the connecting blobs
        [X,Y] = meshgrid(1:bb(3)+1,1:bb(4)+1);
        XE = round(X + of.Vx);
        YE = round(Y + of.Vy);
        XE(XE>bb(3)) = bb(3);
        YE(YE>bb(4)) = bb(4);
        XE(XE<1) = 1;
        YE(YE<1) = 1;
        LABELP = Trck.prevfrm.antblob.LABEL(bb(2):bb(2)+bb(4),bb(1):bb(1)+bb(3));
        LABELC = Trck.currfrm.antblob.LABEL(bb(2):bb(2)+bb(4),bb(1):bb(1)+bb(3));
        BE = LABELC(sub2ind([bb(4)+1,bb(3)+1],YE,XE));
        for j=1:length(previx)
            endblobs = BE(LABELP==previx(j));
            endblobs = endblobs(endblobs>0);
            uendblobs = unique(endblobs);
            for k=1:length(uendblobs)
                Trck.ConnectArray(previx(j),uendblobs(k)) = nnz(endblobs==uendblobs(k));
                Trck.ConnectArraybin(previx(j),uendblobs(k)) = Trck.ConnectArray(previx(j),uendblobs(k))>Trck.get_param('linking_flow_cutoff');
            end
        end
        
        
        if Trck.get_param('linking_low_fps_hack')
            low_framerate_hack
        end
        
    end

end



    function low_framerate_hack()
        %
        % this is a hack for low frame rate movies, where fast ants
        % "escape" the OF connection. we assume they are still in the
        % cluster
        
        if ~isempty(currix) && ~isempty(previx) && numel(currix)+numel(previx)>2
            
        % find unconnected blobs
        CAB = Trck.ConnectArraybin(previx,currix);
        prev_unconnected = find(sum(CAB,2)==0);
        curr_unconnected = find(sum(CAB,1)==0);
        
        % if there is one in each frame, connect
        if numel(prev_unconnected)==1 && numel(curr_unconnected)==1      
            Trck.ConnectArraybin(previx(prev_unconnected),currix(curr_unconnected)) = true;
        elseif numel(prev_unconnected)==1 && numel(curr_unconnected)==0
            
        % find the area gain/loss of each current frame blob 
        curr_area_gain=[];
        for j=1:length(currix)
             curr_area_gain(j) = Trck.currfrm.antblob.rarea(currix(j)) - sum(Trck.prevfrm.antblob.rarea(CAB(:,j)));
        end
        
        % if there is a blob in current that gained more area than the total area of its
        % linked previous blobs, connect it to the unconnected previous
        % blob       
        if nnz(curr_area_gain>Trck.get_param('thrsh_meanareamin'))==1
             Trck.ConnectArraybin(previx(prev_unconnected),currix(argmax(curr_area_gain))) = true;
        end
       
        elseif numel(prev_unconnected)==0 && numel(curr_unconnected)==1
        
        % find the gain/loss of each previous frame blob
        prev_area_loss = [];
        for jj=1:length(previx)
             prev_area_loss(jj) =  Trck.prevfrm.antblob.rarea(previx(jj)) - sum(Trck.currfrm.antblob.rarea(CAB(jj,:)));
        end
        
        % if there is a blob in previous that lossed more area than its
        % linked current blobs area, connect it to the unconnected current
        % blob
        if nnz(prev_area_loss>Trck.get_param('thrsh_meanareamin'))==1
             Trck.ConnectArraybin(previx(argmax(prev_area_loss)),currix(curr_unconnected)) = true;
        end
        
        end
        end
    end


end







