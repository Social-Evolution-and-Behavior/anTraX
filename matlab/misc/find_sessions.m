function sessions = find_sessions(expdir)
% this function will return a list of session name available in expdir,
% sorted from recently loaded to last loaded

    if isa(expdir,'trhandles')
        expdir=expdir.expdir;
    end
    
    if ~isfolder(expdir)
        sessions = {};
        return
    end

    ds = dir(expdir);
    ds = ds([ds.isdir]);
    
    is = false(0);
    
    for i=1:length(ds)
        is(i) = is_session_dir([expdir,filesep,ds(i).name]);
    end
    
    
    ds = ds(is);
    
    if isempty(ds)
        sessions = {};
        return
    end
    
    for i=1:length(ds)
        t(i) = session_time([expdir,filesep,ds(i).name]);
    end

    ds = ds(argsort(t,'descend'));
    
    sessions = {ds.name};


end

function is = is_session_dir(ds)
% sub function to check if directory is session directory 

if ischar(ds)
    ds = {ds};
end

for i=1:length(ds)
    
    d = ds{i};
    
    pdir = [d,filesep,'parameters'];
    file = [pdir,filesep,'Trck.mat'];
    
    is(i) = isfolder(d)...
        && isfolder(pdir)...
        && exist(file,'file')...
        && strcmp(getfield(whos(matfile(file)),'name'),'Trck');
end
end

function t = session_time(ds)

if ischar(ds)
    ds = {ds};
end

for i=1:length(ds)
    
    d = ds{i};
    
    pdir = [d,filesep,'parameters'];
    file = [pdir,filesep,'Trck.mat'];
    
    t(i) = getfield(dir(file),'datenum');
end
end






