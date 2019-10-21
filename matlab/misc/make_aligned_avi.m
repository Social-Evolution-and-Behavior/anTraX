function make_aligned_avi(Trck)

glist = Trck.graphlist;

fps = Trck.er.fps;
avidir = [Trck.trackingdir,'avi',filesep];
mkdir(avidir);
for m=glist
    
    G = Trck.loaddata(m);
    aviout = [avidir,'posture_',num2str(m),'.avi'];
    vw = VideoWriter(aviout);
    
    vw.FrameRate = fps;
    open(vw);
    
    for i=1:length(G.trjs)
        
        ims = G.trjs(i).get_image('all');
        
        
        for j=1:size(ims,4)
            
            % convert to gry
            im = im2double(ims(:,:,:,j));
            im = min(im,[],3);
            
            % some image adjustments
            vmax = max(im(:));
            im(im==0)=1;
            vmin = min(im(:));
            
            im = imadjust(im,[vmin,vmax],[0,1]);
            im = imsharpen(im);
            im = imcomplement(im);
            im = imfill(im,4);
            im = imcomplement(im);
            
            % align image
            %image = imrotate(image,deg(or(i))+90,'bilinear','crop');
            im1=imerode(im>0.5,ones(3));
            im1=bwareafilt(im1,1);
            try
                s=regionprops(im1,'Extrema');
                top=min(s.Extrema(:,2));
                bottom = size(im1,1)-max(s.Extrema(:,2));
                
                if top>bottom
                    im=flipm(im,[1,2]);
                end
            catch
            end
            im = clip(im);
            writeVideo(vw,im);
            
            
            
        end
        
        
        
    end
    close(vw)
end





