function debug_linking(Trck,ff)


Trck.init_ba_obj;
Trck.init_of_obj;

fi=ff-1;
linkfun = Trck.get_param('linking_method');


read_frame(Trck,fi);
detect_blobs(Trck);
read_frame(Trck,ff);
detect_blobs(Trck);
linkfun(Trck);

bw1 = Trck.prevfrm.BW_2;
bw2 = Trck.currfrm.BW_2;

frame1 = Trck.prevfrm.CData;
frame2 = Trck.currfrm.CData;

perim1 = repmat(im2uint8(imdilate(bwperim(bw1),ones(2))),[1,1,3]);
perim2 = repmat(im2uint8(imdilate(bwperim(bw2),ones(2))),[1,1,3]);

im2show1 = perim1;
im2show1(:,:,1:2) = 0;
im2show2 = perim2;
im2show2(:,:,2:3) = 0;

im2show = im2show1 + im2show2 + frame2.*(1-perim2);

image(im2show);

colors={'m','c','y','g'};

for i=1:size(Trck.ConnectArraybin,1)
    targets=find(Trck.ConnectArraybin(i,:));
    for j=1:length(targets)%size(Trck.ConnectArraybin,2)
        t=targets(j);
        if Trck.ConnectArraybin(i,t)>0
            x = [Trck.prevfrm.antblob.DATA.CENTROID(i,1),Trck.currfrm.antblob.DATA.CENTROID(t,1)];
            y = [Trck.prevfrm.antblob.DATA.CENTROID(i,2),Trck.currfrm.antblob.DATA.CENTROID(t,2)];
            pl=line(x,y,'Color',colors{j},'LineWidth',2);
            %set(pl,
            %annotation('textarrow',x,y,'String','y = x ')
        end
    end
end


