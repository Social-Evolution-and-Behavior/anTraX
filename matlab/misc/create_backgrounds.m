function create_backgrounds(Trck, pb)

withpb = nargin>1;

persubdir = Trck.get_param('background_per_subdir');
method = Trck.get_param('background_method');
n = Trck.get_param('background_nframes');
bgdir = [Trck.paramsdir,'backgrounds',filesep];
mkdirp(bgdir);

frame_range = Trck.get_param('background_frame_range');
flist = frame_range(1):min(frame_range(2),Trck.er.totalframenum);
flist = flist(randperm(length(flist),n));
Trck.set_param('background_frame_list',sort(flist));

if withpb
    set(pb,'Indeterminate','off','Message','Reading frames for background','Value',0)
else
    report('I','Computing background for entire experiment')
end

frames = get_frames(Trck,flist);

if withpb
    set(pb,'Indeterminate','on','Message',['Computing background using ',method, ' method']);
else
    report('I','Done reading frames, computing...')
end

bg = calc_bg(frames,method);

imwrite(bg,[bgdir,'background.png'])

if persubdir
    
    for i=1:length(Trck.er.subdirs)
        if withpb
            set(pb,'Indeterminate','off','Message',['Reading frames for subdir background #',num2str(i)],'Value',0)
        else
            report('I',['Computing background for subdir ',num2str(i),'/',num2str(length(Trck.er.subdirs))])
        end
        mi = Trck.er.subdirs(i).mi;
        mf = Trck.er.subdirs(i).mf;
        flist = Trck.er.movies_info(mi).fi:Trck.er.movies_info(mf).ff;
        if length(flist)>n
            flist = flist(randperm(length(flist),n));
        end
        
        frames = get_frames(Trck,flist);
        
        if withpb
            set(pb,'Indeterminate','on','Message',['Computing background using ',method, ' method']);
        else
            report('I','Done reading frames, computing...')
        end
        
        bgi = calc_bg(frames,method);
        imwrite(bgi,[bgdir,'background_',Trck.er.subdirs(i).name,'.png'])
        bg(:,:,:,i) = bgi;
        flists{i} = sort(flist);
    end
    Trck.set_param('background_subdir_frame_lists',flists);    
end

Trck.load_bg;

report('G','Done creating background/s')


function frames = get_frames(Trck,flist)
nframes = length(flist);
flist = sort(flist);


for ii=1:nframes
    if withpb
        pb.Value = ii/nframes; 
    end
    frames(:,:,:,ii) = Trck.er.read(flist(ii));
end
end

function bg = calc_bg(frames,method)

switch method
    case 'max'
        bg = max(frames,[],4);
    case 'median'
        bg = median(frames,4);
    otherwise
        report('E','wrong bg method')
end

end
end


