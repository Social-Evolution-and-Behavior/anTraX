function detect_blobs(Trck,varargin)

p = inputParser;

addRequired(p,'Trck');
addOptional(p,'Background',[]);
addOptional(p,'Mask',Trck.TrackingMask);
addOptional(p,'Frame',[]);
addOptional(p,'ZS',[]);
addOptional(p,'SegmentationThreshold',Trck.get_param('segmentation_threshold'));
parse(p,Trck,varargin{:});

[BG,BGS,BGW] = Trck.get_bg(Trck.currfrm.t);
mask = p.Results.Mask;

if ~isempty(p.Results.Frame)
    frame = p.Results.Frame;
    frame_single = im2single(Frame);
else
    frame = Trck.currfrm.CData;
    frame_single = Trck.currfrm.single;
end

% sometimes during tracking there is a corrupt frame (empty array). We don't
% want the tracking to fail in that case, so we define the frame as the
% background, which will yield no blobs --> all trajectory will be closed.

skipFrame = (Trck.currfrm.dat.interrupt==1) && ~Trck.get_param('videos_track_on_interrupt');

if skipFrame || isempty(frame)
    frame = BG;
end

if isempty(Trck.hblobs)
    init_ba_obj(Trck);
end

%% Image enhancements


frame_corrected_single = frame_single./BGW;
frame_corrected = im2uint8(frame_corrected_single);

if get_param(Trck,'segmentation_illum_correct')
    
    frame = frame_corrected;
    frame_single = frame_corrected_single;
end


%% Image segmentation

Z = imsubtract(BGS,frame_single);
Z = Z.*single(mask);
%Z = applyMasktoIm(Z,mask);

if Trck.get_param('segmentation_local_z_scaling')   
    if isempty(p.Results.ZS)
        A = rgb2gray(BGW);
        w = median(A(Trck.TrackingMask(:,:,1)>0));
        Z = Z*w./BGW;%/w;
    else
        Z = Z.*p.Results.ZS;
    end
end

% threshold the image
if Trck.get_param('segmentation_use_max_rgb')
    ZGRY = max(Z,[],3);
    FGRY = min(frame,[],3);
else
    ZGRY = rgb2gray(Z);
    FGRY = rgb2gray(frame);
end


BW = im2bw(ZGRY,p.Results.SegmentationThreshold);

% filter out small blobs
BW = bwareaopen(BW,round(Trck.get_param('segmentation_MinimumBlobArea')/2),Trck.hblobs.ants.Connectivity);
BW2=BW;

% image closing
if Trck.get_param('segmentation_ImClosing')
    BW2 = imclose(BW2,Trck.get_param('segmentation_ImClosingStrel'));
end

% image openning
if Trck.get_param('segmentation_ImOpenning')
    BW2 = imopen(BW2,Trck.get_param('segmentation_ImOpenningStrel'));
end

BW2 = bwareaopen(BW2,Trck.get_param('segmentation_MinimumBlobArea'),Trck.hblobs.ants.Connectivity);

% apply mask again
BW2 = BW2 & logical(mask(:,:,1));

if Trck.get_param('segmentation_fillHoles') && ~Trck.get_param('segmentation_useConvexHull')
    BW2=imfill(BW2,'holes');
end

if Trck.get_param('segmentation_useConvexHull')
    BW2=bwconvhull(BW2,'objects');
end


% filter out small blobs again
BW2 = bwareaopen(BW2,Trck.get_param('segmentation_MinimumBlobArea'),Trck.hblobs.ants.Connectivity);

Trck.currfrm.Z = Z;
Trck.currfrm.BW = BW;
Trck.currfrm.BW_2 = BW2;
Trck.currfrm.ZGRY = im2single(ZGRY);
Trck.currfrm.grayIm = im2single(FGRY); %rgb2gray(frame_single);

%% Blob detection

ab = antblobobj(Trck);

b = struct;



if Trck.hblobs.ants.PerimeterOutputPort
    [b.AREA,b.CENTROID,b.BBOX,b.MAJAX,b.ORIENT,b.ECCENT,b.PERIMETER,ab.LABEL] = ...
        step(Trck.hblobs.ants,Trck.currfrm.BW_2);
else
    [b.AREA,b.CENTROID,b.BBOX,b.MAJAX,b.ORIENT,b.ECCENT,ab.LABEL] = ...
        step(Trck.hblobs.ants,Trck.currfrm.BW_2);
end

ab.DATA = struct2table(b);


if false %Trck.get_param('segmentation_SplitDoubleAntBlobs')
    
    % find split candidates
    cand = find(ab.rarea > ab.Trck.get_param('thrsh_meanareamax') & ab.rarea < 2*ab.Trck.get_param('thrsh_meanareamax'));
    
    if ~isempty(cand)
        th = ab.Trck.get_param('segmentation_threshold')*1.1;
        [~,bw] = segment_image(Trck,...
            p.Results.Background,...
            p.Results.Mask,...
            Frame,...
            th,...
            p.Results.ImcloseStrel,...
            'UpdateTrck',false);
        bw = imopen(bw,ones(5));
    end
    
    for i=1:length(cand)
        bix = cand(i);
        bwi=bw.*(ab.LABEL==bix);
        LABELi = bwlabel(bwi);
        
        if max(LABELi(:))==2
            [~,IDX] = bwdist(bwi);
            L = (ab.LABEL==bix).*reshape(LABELi(IDX),size(LABELi));
            L1 = imreconstruct(LABELi==1,L==1);
            L2 = imreconstruct(LABELi==2,L==2);
            S1 = regionprops(L1,'BoundingBox','Area','Centroid','Eccentricity','Orientation','MajorAxisLength','Perimeter');
            S2 = regionprops(L2,'BoundingBox','Area','Centroid','Eccentricity','Orientation','MajorAxisLength','Perimeter');
            ab.DATA.AREA(bix) = S1.Area;
            ab.DATA.CENTROID(bix,:) = S1.Centroid;
            ab.DATA.ORIENT(bix) = deg2rad(S1.Orientation);
            ab.DATA.MAJAX(bix)  = S1.MajorAxisLength;
            ab.DATA.ECCENT(bix) = S1.Eccentricity;
            ab.DATA.BBOX(bix,:) = S1.BoundingBox;
            ab.LABEL(L==1) = bix;
            if Trck.hblobs.ants.PerimeterOutputPort
                ab.DATA.PERIMETER(bix) = S1.Perimeter;
            end
            new.AREA = S2.Area;
            new.CENTROID = S2.Centroid;
            new.ORIENT = deg2rad(S2.Orientation);
            new.MAJAX  = S2.MajorAxisLength;
            new.ECCENT = S2.Eccentricity;
            new.BBOX = S2.BoundingBox;
            if Trck.hblobs.ants.PerimeterOutputPort
                new.PERIMETER = S2.Perimeter;
            end
            ab.DATA = [ab.DATA;struct2table(new)];
            ab.LABEL(L==2)=ab.Nblob;
        end
    end
    
end


S = regionprops(ab.LABEL,Trck.currfrm.ZGRY,'MaxIntensity','MeanIntensity');
ab.DATA.MAXZ = cat(1,S.MaxIntensity);
ab.DATA.MEANZ = cat(1,S.MeanIntensity);

S = regionprops(ab.LABEL,Trck.currfrm.grayIm,'MinIntensity','MeanIntensity');
ab.DATA.MAXINT = 1-cat(1,S.MinIntensity);
ab.DATA.MEANINT = 1-cat(1,S.MeanIntensity);

if Trck.get_param('geometry_open_boundry')
    S = regionprops(ab.LABEL,Trck.Masks.open_boundry_perimeter(:,:,1),'MaxIntensity');
    ab.DATA.ONBOUNDRY = cat(1,S.MaxIntensity)>0;
else
    ab.DATA.ONBOUNDRY = false(size(ab.DATA.MAXINT));
end

% placeholder for dt
ab.DATA.dt = nan(size(ab.DATA.AREA));

if Trck.get_param('segmentation_IntensityFilter')
    ab.filter('MAXZ',Trck.get_param('segmentation_MaxIntensityThreshold'))
end

Trck.currfrm.antblob = ab;

% if need to save ant images
sqsz = Trck.get_param('sqsz');

padded_label = padarray(ab.LABEL,[sqsz/2,sqsz/2]);
padded_frame = padarray(frame_corrected,[sqsz/2,sqsz/2]);
ab.images = zeros([sqsz,sqsz,3,ab.Nblob],'uint8');
if Trck.get_param('tracking_saveimages')
    for i=1:ab.Nblob
        msk = imcrop(padded_label,[ab.DATA.CENTROID(i,1),ab.DATA.CENTROID(i,2),sqsz-1,sqsz-1])==i;
        img = imcrop(padded_frame,[ab.DATA.CENTROID(i,1),ab.DATA.CENTROID(i,2),sqsz-1,sqsz-1]);
        img = applyMasktoIm(img,msk);
        ab.images(:,:,:,i) = img;
    end
end


