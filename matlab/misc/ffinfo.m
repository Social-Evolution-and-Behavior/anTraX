function info = ffinfo(file)
% get movie file info with ffprobe

debug_mode = strcmp(getenv('ANTRAX_DEBUG_MODE'),'True');

if strcmp(computer,'MACI64')
    if ~contains(getenv('PATH'),'/usr/local/bin')
        setenv('PATH', [getenv('PATH') ':/usr/local/bin']);
    end
end

[~,ffprobe] = system('which ffprobe');
ffprobe = ffprobe(1:end-1);

if ~isfile(ffprobe)
    report('E', 'Could not locate ffprobe')
    error('Could not locate ffprobe')
end

[~,out]=system([ffprobe ' -v error -show_entries format=format_name,size -of default=noprint_wrappers=1:nokey=1 ''',file,'''',' 2> /dev/null']);

if debug_mode
   
    report('D', ['Running ffprobe #1 for file ', file]);
    fprintf(['\n',out,'\n'])
end

out = strsplit(out);
info.container = out{1};
info.filesize = str2double(out{2});

[~,out]=system([ffprobe ' -v error -show_entries stream=start_time,duration,pix_fmt,width,height,avg_frame_rate,nb_frames -of default=noprint_wrappers=1:nokey=1 ''',file,'''',' 2> /dev/null']);

if debug_mode
   
    report('D', ['Running ffprobe #2 for file ', file]);
    fprintf(['\n',out,'\n'])
end

%disp(out)
try
out = strsplit(out);
info.width = str2double(out{1});
info.height = str2double(out{2});
info.pixel = out{3};
info.fps = eval(out{4});
info.starttime = str2double(out{5});
info.duration = str2double(out{6});

info.nframes = str2double(out{7});
info.channels = 3;
info.framesize = [info.width,info.height,info.channels];
info.framebytes = prod(info.framesize);
catch
    report('D', ['issues with ffprobe output for file ', file]);
    info.width=nan;
    info.height=nan;
    info.pixel=nan;
    info.fps=nan;
    info.starttime=nan;
    info.duration=nan;
    info.nframes=nan;
    info.channels=nan;
    info.framesize=nan;
    info.framebytes=nan;
end
    

if isnan(info.nframes)
    report('W','Number of frames in file is not available for ffprobe. estimating from duration')
    info.nframes = round(info.duration * info.fps);
end
