function xy = filter_jumps(xy,dmax)

d = sqrt(sum((xy(2:end,1:2) - xy(1:end-1,1:2)).^2,2));

ix = find(d>dmax);

xy(ix+1,:) = NaN;