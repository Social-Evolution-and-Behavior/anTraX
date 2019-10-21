function update_tracklets(Trck)

G = Trck.G;

[trj_list,blob_list] = decide_update_status(Trck);

% updating trajectories
Trck.currfrm.antblob.blobID(blob_list.updating) = trj_list.updating_id;
trj_list.updating_ref.add_blob(Trck,blob_list.updating);

% give unique IDs to opening blobs
used_id = setdiff(Trck.tmp.IDlist,trj_list.closing_id);
maxid = max([used_id,0])+length(blob_list.opening)+1;
available_id = sort(setdiff(1:maxid,used_id));
%available_id = sort(setdiff(1:TRAJ.Trck.hblobs.ants.MaximumCount,used_id));
new_id = available_id(1:length(blob_list.opening));
Trck.currfrm.antblob.blobID(blob_list.opening) = new_id;

% closing trajectories
trj_list.closing_ref.close(Trck);

% open new trajectories
G.new_tracklet(blob_list.opening);

% update ID list
Trck.tmp.IDlist =  Trck.currfrm.antblob.blobID;

end




function [trjIDs,blobnum] = decide_update_status(Trck)

trjIDs  = struct('updating_id',[],'updating_ref',tracklet.empty,'closing_id',[],'closing_ref',tracklet.empty);
blobnum = struct('updating',[],'opening',[]);

% if movie changed, close and open all
if Trck.currfrm.movnum ~= Trck.prevfrm.movnum
    if isfield(Trck.prevfrm,'antblob') && ~isempty(Trck.prevfrm.antblob.Nblob) && Trck.prevfrm.antblob.Nblob>0
        trjIDs.closing_ref = Trck.prevfrm.antblob.trj;
        trjIDs.closing_id  = torow(Trck.prevfrm.antblob.blobID);
    end
    blobnum.opening = 1:Trck.currfrm.antblob.Nblob;
    return
end

% if more than 1 frame skip
dt = Trck.currfrm.dat.tracking_dt;
if dt>2.5*Trck.er.framerate
    if isfield(Trck.prevfrm,'antblob') && ~isempty(Trck.prevfrm.antblob.Nblob) && Trck.prevfrm.antblob.Nblob>0
        trjIDs.closing_ref = Trck.prevfrm.antblob.trj;
        trjIDs.closing_id  = torow(Trck.prevfrm.antblob.blobID);
    end
    blobnum.opening = 1:Trck.currfrm.antblob.Nblob;
    
    % if more than 3, do not assign tracklet parenthood
    if dt>3.5*Trck.er.framerate
        Trck.ConnectArraybin = false(size(Trck.ConnectArraybin));
    end
    
    return
end

% for each blob in the previous frame
for nblob = 1:Trck.prevfrm.antblob.Nblob
    % find the corresponding trajectoryID
    which_ID = Trck.prevfrm.antblob.blobID(nblob);
    which_ref = Trck.prevfrm.antblob.trj(nblob);
    %
    islong =  Trck.get_param('tracking_max_tracklet_length')>0 && which_ref.len>=Trck.get_param('tracking_max_tracklet_length');
    % determine which blob it is connected to in the current frame
    currblobconnect = torow(find(Trck.ConnectArraybin(nblob,:)));
    % if it's not connected to only one blob
    if size(currblobconnect,2)~=1 || islong
        % add it to list of closing trajectories
        trjIDs.closing_id = cat(2,trjIDs.closing_id,which_ID);
        trjIDs.closing_ref = cat(2,trjIDs.closing_ref,which_ref);
        % add the connecting blobs to the list of opening trajectories
        blobnum.opening = cat(2,blobnum.opening,currblobconnect);
    end
end

% for each blob in the current frame
for nblob = 1:Trck.currfrm.antblob.Nblob
    % determine which blob it is connected to in the previous frame
    prevblobconnect = torow(find(Trck.ConnectArraybin(:,nblob)));
    % if it's not connected to only one blob
    if size(prevblobconnect,2)~=1
        % find the IDs of the corresponding trajectories
        which_IDs = torow(Trck.prevfrm.antblob.blobID(prevblobconnect));
        which_refs = torow(Trck.prevfrm.antblob.trj(prevblobconnect));
        % add it to list of closing trajectories
        trjIDs.closing_id = cat(2,trjIDs.closing_id,which_IDs);
        trjIDs.closing_ref = cat(2,trjIDs.closing_ref,which_refs);
        % add the connecting blobs to the list of opening trajectories
        blobnum.opening = cat(2,blobnum.opening,nblob);
    end
end
% Each opening blob can appear only once
blobnum.opening = unique(blobnum.opening);

% Each closing trajectory can appear only once
trjIDs.closing_id = unique(trjIDs.closing_id);
trjIDs.closing_ref = unique(trjIDs.closing_ref);

% the blob that don't correspond to an open trajectory must be updated
blobnum.updating = torow(setdiff(1:Trck.currfrm.antblob.Nblob,blobnum.opening));

% for each opening blob
for nblob = blobnum.updating
    % find its connected blob in the previous frame
    prevblobconnect = torow(find(Trck.ConnectArraybin(:,nblob)));
    % find the corresponding ID
    which_ID = torow(Trck.prevfrm.antblob.blobID(prevblobconnect));
    which_ref = torow(Trck.prevfrm.antblob.trj(prevblobconnect));
    % add it to the list of updating trajectories
    trjIDs.updating_id = cat(2,trjIDs.updating_id,which_ID);
    trjIDs.updating_ref = cat(2,trjIDs.updating_ref,which_ref);
end

% disconnect tracklets which touch open boundries
if Trck.get_param('geometry_open_boundry')
    prev_touching = false(size(trjIDs.updating_ref))';
    for i=1:length(trjIDs.updating_ref)
        prev_touching(i) = trjIDs.updating_ref(i).ONBOUNDRY(trjIDs.updating_ref(i).len);
    end
    curr_touching = Trck.currfrm.antblob.DATA.ONBOUNDRY(blobnum.updating);
    
    disconnect = prev_touching ~= curr_touching;
    
    trjIDs.closing_id = cat(2,torow(trjIDs.closing_id), torow(trjIDs.updating_id(disconnect)));
    trjIDs.closing_ref = cat(2,torow(trjIDs.closing_ref), torow(trjIDs.updating_ref(disconnect)));
    trjIDs.updating_id = torow(trjIDs.updating_id(~disconnect));
    trjIDs.updating_ref = torow(trjIDs.updating_ref(~disconnect));
    
    blobnum.opening = cat(2,torow(blobnum.opening), torow(blobnum.updating(disconnect)));
    blobnum.updating = torow(blobnum.updating(~disconnect));
    
end



end



