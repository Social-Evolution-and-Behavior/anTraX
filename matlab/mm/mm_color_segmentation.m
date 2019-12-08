function J = mm_color_segmentation(I, params)

params.color_segmentation_sd = 48;
params.color_segmentation_threshold = 0.2;

params.color_segmentation_bgcolors = [255,255,255;
            236,205,175;
            255,179,172;
            213,175,139];
        
params.color_segmentation_antcolors = [238,98,176;
             255,97,200;
             146,61,136;
             156,58,147;
             255,125,132;
             147,184,255;
             145,190,255;
             125,117,201;
             127,127,255;
             255,128,97;
             168,170,157;
             172,174,150;
             166,210,120;
             230,180,53;
             241,202,10;
             176,75,218;
             178,74,241;
             255,94,224;
             255,83,186];


if I(1,1,1,1)==0
    gry = repmat(min(I,[],3),[1,1,3,1]);
    I(gry==0)=255;
end


I = permute(I,[4,1,2,3]);

sz = size(I);

II = double(reshape(I,[sz(1)*sz(2)*sz(3),3]));

dbg = min(pdist2(II,params.color_segmentation_bgcolors),[],2);
dant = min(pdist2(II,params.color_segmentation_antcolors),[],2);
pbg = normpdf(dbg,0,params.color_segmentation_sd);
pant = normpdf(dant,0,params.color_segmentation_sd);

JJ = pant./(pant+pbg);

a = params.color_segmentation_threshold;

JJ(JJ<a) = a;
JJ(JJ>1-a) = 1-a;
JJ = (JJ-a)/(1-2*a);

J = reshape(JJ,[sz(1),sz(2),sz(3)]);
J = permute(J,[2,3,1]);

for k=1:size(J,3)
    J(:,:,k) = imimposemin(J(:,:,k),J(:,:,k)==0);
end
J(J<0)=0;
J(J>1)=1;
J = reshape(J,[sz(2),sz(3),1,sz(1)]);