function import_params(Trck, filename)

% load main parameter table
if exist(filename,'file') && strcmp(filename(end-4:end),'.json')
    
    f = fopen(filename);
    s = fscanf(f, '%s');
    prmtrs = jsondecode(s);
    fclose(f);
    Trck.prmtrs = prmtrs;
else
    disp(filename)
end
