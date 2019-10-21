function J=classify_and_solve(expdirs,nw)

if nargin<2
    nw=-1;
end

for i=1:length(expdirs)
    classify_batch(expdirs{1},'NumWorkers',nw);
end

for i=1:length(expdirs)
    J(i)=solve_batch(expdirs{i},'NumWorkers',nw);
end