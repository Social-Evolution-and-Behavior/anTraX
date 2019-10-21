function export_cropped_ant_videos(Trck, targetdir, movlist, varargin)


p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addRequired(p,'targetdir');
addOptional(p,'movlist',Trck.movlist);
addParameter(p,'minlength',0);
addParameter(p,'montage',false)
addParameter(p,'align',false)

parse(p,Trck,targetdir,movlist,varargin{:});


movlist = torow(p.Results.movlist);



for m=movlist
    
    report('I',['Exporting clips from movie ',num2str(m)]); 
    images = load([Trck.imagedir,'images_',num2str(m),'.mat']);
    tracklets = fieldnames(images);
    
    clear ff fi len
    
    for i=1:length(tracklets)
        s = strsplit(tracklets{i},'_');
        fi(i) = str2double(s{4});
        ff(i) = str2double(s{6});
    end
    
    len = ff-fi+1;
    
    tracklets = tracklets(len>=p.Results.minlength);
    
    for i=1:length(tracklets)
        
        ims = images.(tracklets{i});
        ims = double(ims)/255;
        ims = min(ims,[],3);
        
        ims(ims==0)=1;
        ims = ims * 1/0.6 - 1/6;
        ims(ims<0)=0;
        ims(ims>1)=1;
        
        ims = repmat(ims,[1,1,3,1]);
        
        
        if p.Results.align
            clear to_flip
            
            for k=1:size(ims,4)
                bw=bwareafilt(ims(:,:,1,k)<1,1);
                S=regionprops(bw,1-ims(:,:,1,k),'WeightedCentroid');
                to_flip(k) = S.WeightedCentroid(2)+0.5<size(ims,1)/2;
            end
            
            ims(:,:,:,to_flip) = flipm(ims(:,:,:,to_flip),1);
        end
        
        mov = immovie(ims);
        vw = VideoWriter([p.Results.targetdir,filesep,tracklets{i},'.avi']);
        open(vw);
        vw.writeVideo(mov);
        close(vw);
        
    end
    
    
    
end



