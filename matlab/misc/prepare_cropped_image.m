function im = prepare_cropped_image(im,angle)



im = imrotate(im,angle,'nearest','crop');

ggry=max(im,[],3);
msk=ggry==0;
imagesc(msk)
msk3=repmat(msk,[1,1,3]);
im(msk3)=255;


