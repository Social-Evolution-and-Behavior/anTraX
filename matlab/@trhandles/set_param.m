function set_param(Trck,pname,pval)

Trck.prmtrs.(pname) = pval;

switch pname
    case 'segmentation_ImClosingSize'
        Trck.prmtrs.segmentation_ImClosingStrel = strel('disk',Trck.prmtrs.segmentation_ImClosingSize);
    case 'segmentation_ImOpenningSize'
        Trck.prmtrs.segmentation_ImOpenningStrel = strel('disk',Trck.prmtrs.segmentation_ImOpenningSize);
    %case 'segmentation_threshold'
    %    Trck.prmtrs.segmentation_threshold_image = 
end

Trck.save_params;
