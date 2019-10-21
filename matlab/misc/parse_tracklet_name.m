function [ti,tf] = parse_tracklet_name(Trck,trj_name)


s = strsplit(trj_name,'_');

mi  = str2double(s{3}(3:end));
mfi = str2double(s{4});

mf  = str2double(s{5}(3:end));
mff = str2double(s{6});

ti = trtime(Trck,mi,mfi);
tf = trtime(Trck,mf,mff);
