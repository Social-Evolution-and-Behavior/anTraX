function load_params(Trck)


% load main parameter table
if exist([Trck.paramsdir,'prmtrs.mat'],'file')
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

% load colors and labels
Trck.load_labels;