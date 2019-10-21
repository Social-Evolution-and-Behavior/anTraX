function recents = load_recent_expdirs()


antraxdir = [getenv('HOME'),filesep,'.antrax',filesep];
mkdirp(antraxdir);

recent_expdirs_file = [antraxdir,'recent_expdirs.txt'];

recents = {};

if exist(recent_expdirs_file,'file')
    recents = readcell(recent_expdirs_file,'Delimiter','|');
end

is = cellfun(@(x) is_expdir(x,true), recents);
recents = recents(is);
