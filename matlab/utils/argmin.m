function ix = argmin(a,k)
if nargin==1 || k==1
    [~,ix] = min(a);
else
    ix = argsort(a);
    ix = ix(1:k);
end
