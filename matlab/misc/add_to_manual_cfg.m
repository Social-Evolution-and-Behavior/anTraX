function add_to_manual_cfg(Trck, tracklet, command, id)

file = [Trck.paramsdir,'prop.cfg'];
line = [command, ' ', tracklet, ' ', id];
fid = fopen(file, 'a+');
fprintf(fid, '%s\n', line);
fclose(fid);