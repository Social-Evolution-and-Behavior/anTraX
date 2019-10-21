function save_labels(Trck)


% save labels info as csv file
categories = fieldnames(Trck.labels);
%categories = setdiff(categories, 'tagcolors');

A = {};
for i=1:length(categories)
    c = categories{i};
    labs = tocol(Trck.labels.(c));
    Ai = [labs,repmat({c},size(labs))];
    A = cat(1,A,Ai);
end

writecell(A,[Trck.paramsdir,'labels.csv'],'Delimiter','\t');

if exist([Trck.paramsdir,'labels.mat'],'file')
    delete([Trck.paramsdir,'labels.mat']);
end


