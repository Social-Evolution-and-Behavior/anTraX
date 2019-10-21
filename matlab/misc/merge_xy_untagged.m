function merge_xy_untagged(Trck,movlist,c)


if nargin>2
    wd = [Trck.trackingdir,'antdata',filesep,Trck.colony_labels{c},filesep];
elseif Trck.Ncolonies==1
    wd = [Trck.trackingdir,'antdata',filesep];
else
    for c=1:Trck.Ncolonies
        merge_xy_untagged(Trck,movlist,c);
    end
    return
end


mi = movlist(1);
mf = movlist(end);
data = struct('xy',[],'frame',[],'nants',[],'area',[],'orient',[]);
flds = fieldnames(data);
for m=mi:mf
    disp(num2str(m))
    datam = load([wd,'/xy_',num2str(m),'_',num2str(m),'.mat']);
    for k=1:length(flds)
        data.(flds{k}) = cat(1,data.(flds{k}),datam.(flds{k}));
    end
    
end
save([wd,'xy_',num2str(mi),'_',num2str(mf),'.mat'],'-struct','data','-v7.3');


if exist([wd,'exits_entrances_',num2str(m),'.mat'],'file')
    
exit_times_sd = [];
entrance_times_sd = [];
for m=mi:mf
    load([wd,'exits_entrances_',num2str(m),'.mat']);
    exit_times_m = exit_times + Trck.er.movies_info(m).fi - 1;
    entrance_times_m = entrance_times + Trck.er.movies_info(mi).fi - 1;
    exit_times_sd = cat(2,exit_times_sd,exit_times_m);
    entrance_times_sd = cat(2,entrance_times_sd,entrance_times_m);
end
exit_times = exit_times_sd;
entrance_times = entrance_times_sd;
save([wd,'exits_entrances_',num2str(mi),'_',num2str(mf),'.mat'],'exit_times','entrance_times','-v7.3');


end