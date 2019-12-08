function bbox = squarebbox(I, margin)


if nargin<2
    margin = 0;
end

bbox = regionprops(I,'BoundingBox');
bbox = bbox.BoundingBox;

x = bbox(1);
y = bbox(2);
w = bbox(3);
h = bbox(4);

if w>h
    
    y = y - (w-h)/2;
    h = w;
    
else
    
    x = x - (h-w)/2;
    w = h;
    
end

x = x - margin;
y = y - margin;
h = h + 2*margin;
w = w + 2*margin;

bbox = round([x, y, w, h]);


    
