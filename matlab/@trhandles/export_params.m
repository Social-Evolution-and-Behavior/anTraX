function export_params(Trck,filename)

% save main paramter struct
prmtrs = Trck.prmtrs;
struct2json(prmtrs,filename)

