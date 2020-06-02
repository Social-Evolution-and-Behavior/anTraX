function xy = interpolate_xy(xy, maxd, maxf)

if nargin<2
    maxd = inf;
end

if nargin<3
    maxf = inf;
end


allix = 1:size(xy,1);
nanmask = isnan(xy(:,1));

interpmask = nanmask;

[sqlen,~,sqstart,sqend] = divide2seq(nanmask);

for k=1:length(sqlen)
    if sqstart(k)==1 || sqend(k)==length(allix)
        interpmask(sqstart(k):sqend(k)) = false;
        continue
    end
    dt = sqlen(k);
    dd = sqrt(sum((xy(sqend(k)+1,1:2) - xy(sqstart(k)-1,1:2)).^2));
    if dt > maxf || dd > maxd
        interpmask(sqstart(k):sqend(k)) = false;
    end
end

if nnz(interpmask)>0
    xy(interpmask,1) = interp1(allix(~nanmask),xy(~nanmask,1),allix(interpmask));
    xy(interpmask,2) = interp1(allix(~nanmask),xy(~nanmask,2),allix(interpmask));
    if size(xy,2)>3
        xy(interpmask,4) = 5;
    end
end