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
save(filename,'prmtrs');
struct2json(prmtrs,jsonfile)

% save color and label info
Trck.save_labels;
