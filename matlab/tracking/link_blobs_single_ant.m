function link_blobs_single_ant(Trck)

% initialize connection matrices
Trck.ConnectArray=zeros(Trck.prevfrm.antblob.Nblob,Trck.currfrm.antblob.Nblob);
Trck.ConnectArraybin=zeros(Trck.prevfrm.antblob.Nblob,Trck.currfrm.antblob.Nblob,'logical');

% if no blob present in current or previous frame, skip
if Trck.currfrm.antblob.Nblob==0 || Trck.prevfrm.antblob.Nblob==0
    return
end

% some more blob filtering
idx2remove = Trck.currfrm.antblob.DATA.ECCENT >0.99 & Trck.currfrm.antblob.DATA.AREA < 2*Trck.hblobs.ants.MinimumBlobArea;% & Trck.currfrm.antblob.DATA.MAXINT < 0.8;

Trck.currfrm.antblob.remove(idx2remove);

if Trck.currfrm.antblob.Nblob==0
    return
end

% partition to clusters
msk = logical(Trck.Masks.roi(:,:,1));
cluster_label = bwlabel(msk);
blobclusterprev = cluster_label(sub2ind(size(cluster_label),round(Trck.prevfrm.antblob.DATA.CENTROID(:,2)),round(Trck.prevfrm.antblob.DATA.CENTROID(:,1))));
blobclustercurr = cluster_label(sub2ind(size(cluster_label),round(Trck.currfrm.antblob.DATA.CENTROID(:,2)),round(Trck.currfrm.antblob.DATA.CENTROID(:,1))));


KEEP=[];

for i=1:max(cluster_label(:))
    
    previx = find(blobclusterprev==i);
    currix = find(blobclustercurr==i);
    
    if numel(previx)==0 || numel(currix)==0 || numel(previx)>1
        
        if numel(currix)>1 
            keep = argmax(Trck.currfrm.antblob.rarea(currix));
            KEEP = [KEEP;keep];
        else
            KEEP = [KEEP;currix];
        end
        continue
    end
    
    if numel(currix)>1
        
        d = pdist2(Trck.prevfrm.antblob.rcentroid(previx,:),Trck.currfrm.antblob.rcentroid(currix,:),'euclidean');
        
        if max(d)/min(d)>5
            keep = argmin(d);
        else
            keep = argmax(Trck.currfrm.antblob.rarea(currix));
        end
        
        keep = currix(keep);
        currix = keep;
        KEEP = [KEEP;keep];
        
    else
        KEEP = [KEEP;currix];
    end

    Trck.ConnectArraybin(previx,currix)=true;

end

% remove unconnected blobs
REMOVE = true(Trck.currfrm.antblob.Nblob,1);
REMOVE(KEEP) = false;
if nnz(REMOVE)
    Trck.currfrm.antblob.remove(REMOVE);
    Trck.ConnectArraybin=Trck.ConnectArraybin(:,~REMOVE);
end

