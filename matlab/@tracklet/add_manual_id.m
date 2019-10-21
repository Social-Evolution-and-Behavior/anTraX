function add_manual_id(trj,varargin)

if ~isscalar(trj)
    for i=1:length(trj)
        add_manual_id(trj(i),varargin{:});
    end
    return
end



Trck = trj.Trck;
p = inputParser;
addRequired(p,'trj',@(x) isa(x,'tracklet'));
addRequired(p,'id',@ischar);
addParameter(p,'frame',[]);
addParameter(p,'frameindex',[]);
addParameter(p,'flip',false,@islogical);

% parse inputs
parse(p,trj,varargin{:});

if isempty(Trck.manualIDs)
    Trck.loadManualIDs;
end

if ~ismember(p.Results.id,cat(1,tocol(Trck.labels.ant_labels),tocol(Trck.labels.nonant_labels))) && ~strcmp(p.Results.id,'Unknown')
    report('E','provided id not in label list')
    return
end


mid.tracklet = trj.name;
mid.label = p.Results.id;
mid.flip = p.Results.flip;
mid.colony = trj.colony;
mid.m = trj.m;
mid.len = trj.len;

if isempty(mid.colony)
    mid.colony='C';
end



if isempty(p.Results.frame) && isempty(p.Results.frameindex)
    mid.framenum = trj.fi;
elseif isempty(p.Results.frame) && ~isempty(p.Results.frameindex)
    mid.framenum = trj.fi + p.Results.frameindex-1;
elseif ~isempty(p.Results.frame) && isempty(p.Results.frameindex)
    if isa(p.Results.frame,'trtime')
        mid.framenum = p.Results.frame.f;
    else
        mid.framenum = p.Results.frame;
    end
else
    report('E','cannot provide both frame and frameindex')
    return
end

if mid.framenum<trj.fi || mid.framenum>trj.ff
    report('E','wrond frame for tracklet')
    return
end

% remove old entry if exists
if ismember(mid.tracklet,Trck.manualIDs.tracklet)
    Trck.manualIDs(strcmp(Trck.manualIDs.tracklet,mid.tracklet),:)=[];
end

Trck.manualIDs = [Trck.manualIDs;struct2table(mid)];
Trck.saveManualIDs;
trj.ID(1).manual = p.Results.id;
