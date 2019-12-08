function load_params(Trck)


% load main parameter table
if exist([Trck.paramsdir,'prmtrs.json'],'file')
    try
        f = fopen([Trck.paramsdir,'prmtrs.json']);
        s = fscanf(f, '%s');
        prmtrs = jsondecode(s);
        fclose(f);
    catch
        load([Trck.paramsdir,'prmtrs.mat'],'prmtrs');
    end
    Trck.prmtrs = prmtrs;
else
    Trck.prmtrs = default_params(Trck);
end


Trck.prmtrs.segmentation_ImClosingStrel = strel('disk',Trck.prmtrs.segmentation_ImClosingSize);
Trck.prmtrs.segmentation_ImOpenningStrel = strel('disk',Trck.prmtrs.segmentation_ImOpenningSize);

offlterprmtr = round(50*(Trck.prmtrs.geometry_scale0/Trck.prmtrs.geometry_rscale));
Trck.prmtrs.linking_offilter = fspecial('gaussian',[offlterprmtr offlterprmtr], 2);


% load colors and labels
Trck.load_labels;