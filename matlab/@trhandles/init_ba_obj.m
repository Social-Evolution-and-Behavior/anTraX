function init_ba_obj(Trck)

imsz = Trck.er.width * Trck.er.height;

Trck.hblobs.ants = vision.BlobAnalysis; 
Trck.hblobs.ants.AreaOutputPort = true;
Trck.hblobs.ants.CentroidOutputPort = true;
Trck.hblobs.ants.BoundingBoxOutputPort = true;
Trck.hblobs.ants.EccentricityOutputPort = true;
Trck.hblobs.ants.Connectivity = 8;
Trck.hblobs.ants.OrientationOutputPort = true;
Trck.hblobs.ants.PerimeterOutputPort = true;
Trck.hblobs.ants.MajorAxisLengthOutputPort = true;
Trck.hblobs.ants.MinorAxisLengthOutputPort = false;

Trck.hblobs.ants.MaximumCount = max([floor(imsz/10),1000]);
Trck.hblobs.ants.LabelMatrixOutputPort = true;
% Trck.hblobs.ants.NumBlobsOutputPort = true;
Trck.hblobs.ants.MinimumBlobAreaSource = 'Property';
% this is required to be in pixels, hence the 21 (determined by reference movie) and the weird way to deal with change of scale
%Trck.hblobs.ants.MinimumBlobArea = round(21*(Trck.get_param('geometry_scale0')/Trck.get_param('geometry_rscale'))^2);
Trck.hblobs.ants.MinimumBlobArea = Trck.get_param('segmentation_MinimumBlobArea');
% This stays in pixels warning('parameters used to be round(21*(Trck.scale0/Trck.prmtrs.XYRefs.rscale)^2) before 01/09/16')

Trck.hblobs.ants.MaximumBlobAreaSource = 'Property';
% Trck.hblobs.ants.MaximumBlobArea = ;
Trck.hblobs.ants.OutputDataType = 'double';