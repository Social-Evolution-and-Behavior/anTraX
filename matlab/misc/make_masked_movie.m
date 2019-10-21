function make_masked_movie(Trck,m,vidfilename)





vw = VideoWriter(vidfilename,'Motion JPEG AVI');
vw.Quality = 95;
vw.FrameRate = 30;
open(vw);

fi = Trck.er.movies_info(m).fi;
ff = Trck.er.movies_info(m).ff;


msk1 = Trck.Masks.roi(:,:,1);
msk3 = Trck.Masks.roi;
perim = imdilate(bwperim(Trck.Masks.roi(:,:,1)),ones(5));
perim3 = repmat(perim,[1,1,3]);
bg = Trck.Backgrounds.bg;

for f=fi:10:ff
    
    
    frame = Trck.er.read_frame(f);
    frame = 255 - (bg - frame);
    frame(~msk3) = 255;
    frame(perim3) = 96;
    writeVideo(vw,frame);
end


close(vw);