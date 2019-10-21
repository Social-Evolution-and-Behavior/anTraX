function med = wmed(x,w)


if isvector(x) && isvector(w) && length(x)~=length(w)
    error('w and x must be of same length')
end

if ~isvector(x) && isvector(w) && size(x,1)~=length(w)
    error('number of rows in x must equal length of w')
end

if ~~isvector(x) && isvector(w) && (size(x,1)~=size(w,1) || size(x,2)~=size(w,2))
    error('w and x must be of same size')
end

    
if isvector(x)
    x = tocol(x);
end

if isvector(w)
    w = tocol(w);
    if ~isvector(x)
        w = repmat(w,1,size(x,2));
    end
end


for i=1:size(x,2)
    [xs,ix]=sort(x(:,i));
    ws = w(ix,i);
    ws = ws/sum(ws);
    cws = cumsum(ws);
    imed = find(cws>=0.5,1,'first');
    if cws(imed)>0.5
        med(1,i) = xs(imed);
    else
        med(1,i) = mean(xs(imed:imed+1));
    end
end
