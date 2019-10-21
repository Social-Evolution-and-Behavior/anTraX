function wm = wmean(X,w)
% This function computes the mean of the the observations in X, weighted by
% the weights in w. Length of w must be the same as the number of rows in
% X.

N = size(X,2);  % number of dimensions
K = size(X,1);  % number of observations

if nargin==1 || isempty(w) || isscalar(w)
    w = ones(K,1);
elseif ~isvector(w) || length(w)~=K
    error('w must be a vector of length equals to the number of rows in X')
elseif nnz(w)==0
    error('w must have at least one non zero weight')
end

w = tocol(w);

wm = w'*X/sum(w);


