function load_labels(Trck)

if exist([Trck.paramsdir,'labels.mat'],'file')

    load([Trck.paramsdir,'labels.mat']);
    Trck.labels = labels;
    Trck.save_labels;
    
elseif exist([Trck.paramsdir,'labels.csv'],'file')
    labels = struct;
    A = readcell([Trck.paramsdir,'labels.csv']);
    categories = unique(A(:,2));
    for i=1:length(categories)
        c = categories{i};
        ix = strcmp(A(:,2),c);
        labels(1).(c) = torow(A(ix,1));
    end
    
    if ~ismember('ant_labels',categories)
        labels.ant_labels = {};
    end
    
    if ~ismember('noant_labels',categories)
        labels.noant_labels = {};
    end
 
    if ~ismember('NoAnt',labels.noant_labels)
        labels.noant_labels = cat(2,labels.noant_labels,'NoAnt');
    end
    
    if ~ismember('other_labels',categories)
        labels.other_labels = {'Unknown'};
    elseif ~ismember('Unknown',labels.other_labels)
        labels.other_labels = cat(2,labels.other_labels,'Unknown');
    end
    
    Trck.labels = labels;
    


else

    labels.tagcolors = {'B','G','O','P'};
    labels.ant_labels = all_possible_ids(labels.tagcolors);
    labels.nonant_labels = {'NoAnt'};
    labels.other_labels = {'Unknown'};
    Trck.labels = labels;

end
