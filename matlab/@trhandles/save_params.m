function save_params(Trck,suffix)

if nargin<2 || isempty(suffix)
    filename = [Trck.paramsdir,'prmtrs.mat'];
    jsonfile = [Trck.paramsdir,'prmtrs.json'];
else
    filename = [Trck.paramsdir,'prmtrs_',suffix,'.mat'];
    jsonfile = [Trck.paramsdir,'prmtrs_',suffix,'.json'];
end

% save main paramter struct
prmtrs = Trck.prmtrs;

if isfield(prmtrs, 'segmentation_ImClosingStrel')
    prmtrs = rmfield(prmtrs, 'segmentation_ImClosingStrel');
end

if isfield(prmtrs, 'segmentation_ImOpenningStrel')
    prmtrs = rmfield(prmtrs, 'segmentation_ImOpenningStrel');
end

if isfield(prmtrs, 'linking_offilter')
    prmtrs = rmfield(prmtrs, 'linking_offilter');
end

if isfield(prmtrs, 'se_graymask')
    prmtrs = rmfield(prmtrs, 'se_graymask');
end

%save(filename,'prmtrs');
struct2json(prmtrs,jsonfile)

% save color and label info
Trck.save_labels;
