function init(er,force)
% this function initialize the 'expreader' object by extracting information
% about the movies in the experiment directory


if nargin<2
    force = false;
end

% if on RU hpc, always recreate movies_info
if isfolder('/ru-auth/local/home/agal')
    report('W','On RU HPC, recreating movies_info')
    force = true;
    save_movies_info = false;
else
    save_movies_info = true;
end


create_tracking_directory(er)

% if movies_info file exist in expdir, try to read it
if ~force && exist([er.movies_info_file],'file')
    report('I','Reading video information from file')
    T = readtable(er.movies_info_file,'Delimiter',' ','ReadVariableNames',true);
    er.movies_info = table2struct(T);
    er.frame_size = [er.movies_info(1).height,er.movies_info(1).width,er.movies_info(1).channels];
    er.nmovies = length(er.movies_info);
    get_subdirs(er);
    
    try
        ok = exist(er.movfile(1),'file');
    catch
        ok = false;
    end
    
    if ok
        return
    else
        report('W','Video information does not match, initializing..')
    end
end


%% create a list of subdirectories
% subdir names are required to be in the format "i_j", where i and j are the
% indexes of the first and last video files in the subdirectory

get_subdirs(er);
nmovies = sum([er.subdirs.nmovies]);
index_delimiter = '_';


%% create the movie list

% get the format
known_formats = {'.avi','.mov','.mp4'};
filelist = dir([er.subdirs(1).fullpath,'*.*']);
ix = arrayfun(@(x) ~contains(x.name,'.thermal.') && ~startsWith(x.name,'.'),filelist);
filelist=filelist(ix);
for i=1:length(filelist)
    [~,name{i},ext{i}] = fileparts(filelist(i).name);
end
vidext = intersect(unique(ext),known_formats);

if length(vidext)>1
    error('Multiple video format found');
end

vidext = vidext{1};
with_dat = ismember('.dat',ext);

% find out movie name format
if exist([er.subdirs(1).fullpath,er.expname,num2str(er.subdirs(1).mi),vidext],'file')
    % jonathan's old name format
    vid_name_format='expname_index';
else
    vid_name_format='delim_index';
end


er.movies_info = [];
for i=1:length(er.subdirs)
    
    movlist = dir([er.subdirs(i).fullpath,'*',vidext]);
    ix = arrayfun(@(x) ~contains(x.name,'.thermal.') && ~startsWith(x.name,'.'),movlist);
    movlist = movlist(ix);
    mlist = file_index({movlist.name});
    
    
    for j=1:length(mlist) %subdirs(i).nmovies
        
        m = mlist(j);
        er.movies_info(m).index = m;
        er.movies_info(m).subdir = er.subdirs(i).name;
        er.movies_info(m).name = movlist(j).name(1:end-4);
        er.movies_info(m).movfile = movlist(j).name;
        %er.movies_info(m).dir = er.subdirs(i).fullpath;
        
        if ~exist(er.movfile(m),'file')
            report('W',['Can''t find movie file #' num2str(m)])
        end
        
        if with_dat
            er.movies_info(m).datfile = [er.movies_info(m).name,'.dat'];
            if ~exist(er.datfile(m),'file')
                %error('Can''t find dat file')
                report('W',['Can''t find dat file #' num2str(m)])
            end
        end
    end
end

er.movies_info = er.movies_info(argsort([er.movies_info.index]));

% test for continuity
if ~all([er.movies_info.index]==er.movies_info(1).index:er.movies_info(end).index)
    error('Something wrong in movie list, maybe a missing movie?')
end


% TEST THE LAST MOVIE: if it ended due to a computer crashing,it will not be closed properly
% and the movie will not be inaccessible.

try
    % try to open the movie
    testVR = ffreader(er.movfile(length(er.movies_info))); %#ok<NASGU>
    % if it can't be open
catch
    % remove this movie from the list
    report('W','Last movie is corrupt: discarding')
    er.movies_info(end) = [];
end

er.nmovies = length(er.movies_info);

%% if dat has header line, update dat flds info


%% get movie infos


if exist([er.expdir,filesep,'metadata.yaml'],'file')
   
    motif_metadata = ReadYaml([er.expdir,filesep,'metadata.yaml']);
    fps = motif_metadata.acquisitionframerate;
end
    



for i=1:length(er.movies_info)
    mov = er.movfile(i);
    if exist(mov,'file')
        info = ffinfo(mov);
        flds = fieldnames(info);
        
        
        for j=1:length(flds)
            er.movies_info(i).(flds{j})=info.(flds{j});
        end
        
        % for motif videos: take fps from metadata
        if exist([er.expdir,filesep,'metadata.yaml'],'file')
            er.movies_info(i).fps = fps;
            er.movies_info(i).duration = fps * er.movies_info(i).nframes;
        end
        % hack duration and nframes
        if with_dat
            
            % some wierd bug sometimes with readtable..
            % A=readtable(er.movies_info(i).datfile);
            A = importdata(er.datfile(i));
            if isstruct(A)
                A = A.data;
            end
            er.movies_info(i).nframes_avi = er.movies_info(i).nframes;
            er.movies_info(i).duration_avi = er.movies_info(i).duration;
            er.movies_info(i).nframes = size(A,1);
            er.movies_info(i).duration = (er.movies_info(i).nframes-1)/er.movies_info(i).fps;
        end
        
        er.movies_info(i).fi = sum([er.movies_info(1:i-1).nframes])+1;
        er.movies_info(i).ff = sum([er.movies_info(1:i).nframes]);
    end
end

er.frame_size = [info.height,info.width];

if save_movies_info
    T=struct2table(er.movies_info);
    writetable(T,er.movies_info_file,'Delimiter',' ','WriteVariableNames',true);
end



    function m = file_index(fullname)
        
        if isempty(fullname)
            m = [];
            return
        end
        
        if ischar(fullname)
            fullname = {fullname};
        end
        
        for ii=1:length(fullname)
            [~,m_name] = fileparts(fullname{ii});
            if strcmp(vid_name_format,'delim_index')
                nameparts = strsplit(m_name,index_delimiter);
                m(ii) = str2num(nameparts{end});
            elseif strcmp(vid_name_format,'expname_index')
                nameparts = strsplit(m_name,er.expname);
                m(ii) = str2num(nameparts{end});
            end
        end
        
    end







end




function get_subdirs(er)


delim = '_';


subdirs =  dir(er.videodir);

subdirs = subdirs([subdirs.isdir]);


for i = 1:length(subdirs)
    nums = str2double(strsplit(subdirs(i).name,delim));
    if length(nums)==2 && ~isnan(nums(1)) && ~isnan(nums(2))
        subdirs(i).mi = nums(1);
        subdirs(i).mf = nums(2);
        subdirs(i).nmovies =  nums(2)-nums(1)+1;
        subdirs(i).fullpath = [er.videodir subdirs(i).name filesep];
    else
        subdirs(i).mi = nan;
        subdirs(i).mf = nan;
    end
end

if ~isempty(subdirs)
    subdirs = subdirs(~isnan([subdirs.mf]));
end
nsubdirs = length(subdirs);

if nsubdirs==0
    report('W','No movie containing subdirs found')
    er.nmovies=0;
    er.movies_info=struct.empty;
    er.frame_size = [640,480];
    return
end

order = argsort(arrayfun(@(x) str2num(strrep(x.name,'_','')),subdirs),'ascend');
subdirs = subdirs(order);

er.subdirs = subdirs;


end
