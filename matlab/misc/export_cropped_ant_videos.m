function export_cropped_ant_videos(Trck, targetdir, movlist, varargin)


p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addRequired(p,'targetdir');
addParameter(p,'movlist',Trck.movlist);
addParameter(p,'minlength',0);
addParameter(p,'montage',false)
addParameter(p,'align',false)
addParameter(p,'colorsegment',false)

parse(p,Trck,targetdir,movlist,varargin{:});


movlist = torow(p.Results.movlist);


cm = repmat(tocol(linspace(0,1,256)),[1,3]);

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
        sz = size(ims);
        if ~p.Results.colorsegment
            
            ims = double(ims)/255;
            ims = min(ims,[],3);
            
            ims(ims==0)=1;
            ims = ims * 1/0.6 - 1/6;
            ims(ims<0)=0;
            ims(ims>1)=1;
            
            ims = repmat(ims,[1,1,3,1]);
        else
                           
            ims = color_segmentation(ims);
            
        end
        
        if p.Results.align
                        
            for k=1:size(ims,4)
                
                im = ims(:,:,:,k);
                
                bw = bwareafilt(im>0.45,1);
                S = regionprops(bw,'Orientation','Centroid');
                
                im = padarray(im,[sz(1)/2,sz(1)/2,0]);
                im = imcrop(im,[S.Centroid(1),S.Centroid(2),sz(1)-1,sz(1)-1]);
                im = imrotate(im,90-S.Orientation,'crop');
                
                % center of mass
                bw = bwareafilt(im>0.45,1);
                S = regionprops(bw,imopen(im,ones(5)),'WeightedCentroid','Extrema');
                y1 = S.WeightedCentroid(2)+0.5;
                y2 = mean([max(S.Extrema(:,2)),min(S.Extrema(:,2))]);
                
                if  y1 - y2 > 3
                    im = flipm(im,[1,2]);
                end
                
                ims(:,:,:,k) = im;
                
            end
            
      
        end
        

        if max(ims(1,:,:,:),[],'all')>0.5 || max(ims(end,:,:,:),[],'all')>0.5 || max(ims(:,1,:,:),[],'all')>0.5 || max(ims(:,end,:,:),[],'all')>0.5
        
            continue
            
        end
            
        mov = immovie(uint8(ims*256),cm);
        vw = VideoWriter([p.Results.targetdir,filesep,tracklets{i},'.avi']);
        open(vw);
        vw.writeVideo(mov);
        close(vw);
        
    end
    
    
    
end



