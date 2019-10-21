function im = clip(im,range)


if nargin<2
    range = [0,1];
end


im(im<range(1))=range(1);
im(im>range(2))=range(2);
    