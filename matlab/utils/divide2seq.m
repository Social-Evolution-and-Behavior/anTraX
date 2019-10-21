function [sqlen,sqval,sqstart,sqend] = divide2seq(x,v)

[~,~,xu] = unique(x);
sqstart = [1;find(diff(xu)~=0)+1];
sqlen = diff([sqstart;length(x)+1]);
sqval = tocol(x(sqstart));
sqend = sqstart + sqlen - 1;

if nargin>1
    ix = sqval==v;
    sqstart=sqstart(ix);
    sqend=sqend(ix);
    sqlen=sqlen(ix);
    sqval=sqval(ix);
end
   



