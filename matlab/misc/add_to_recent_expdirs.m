function add_to_recent_expdirs(expdir)


antraxdir = [getenv('HOME'),filesep,'.antrax',filesep];
mkdirp(antraxdir);

recent_expdirs_file = [antraxdir,'recent_expdirs.txt'];

recents = {};

if exist(recent_expdirs_file,'file')
    recents = readcell(recent_expdirs_file,'Delimiter','|');
end


if strcmp(expdir(end),'/') || strcmp(expdir(end),'\')
    expdir = expdir(1:end-1);
end

recents = cat(1,{expdir},recents);
recents = unique(recents);

writecell(recents,recent_expdirs_file);

