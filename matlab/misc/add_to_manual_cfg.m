function add_to_manual_cfg(Trck, tracklet, command, value)

file = [Trck.paramsdir,'prop.cfg'];




if islogical(value) || isnumeric(value)
   
    value = num2str(value);
    
end

line = [command, ' ', tracklet, ' ', value];
fid = fopen(file, 'a+');
fprintf(fid, '%s\n', line);
fclose(fid);