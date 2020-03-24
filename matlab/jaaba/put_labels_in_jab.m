function labels_out = put_labels_in_jab(Trck,jab,labelfile)

J = load(jab,'-mat');
T = readtable(labelfile);

T.fi = T.from * Trck.er.fps;
T.ff = T.to * Trck.er.fps;

T.fi(T.fi==0) = 1;
T.ff(T.ff==0) = 1;

behaviors = {};
behaviors1 = J.x.behaviors.names;
for i=1:length(behaviors1)
    if ~strcmp(behaviors1{i}(1:3),'No_')
        behaviors{end+1} = behaviors1{i};
    end
end

exps = unique(T.experiment);


L.t0s = {};
L.t1s = {};
L.names = {};
L.flies = [];
L.off = [];
L.timelinetimestamp = cell(1,0);
L.timestamp = {};
L.imp_t0s = {};
L.imp_t1s = {};

for i=1:numel(J.x.expDirNames)
    labels(i) = L;
end
    


for ie = 1:length(exps)
    
    exp = exps{ie};
    
    expi = find(strcmp(exp,J.x.expDirNames));
    
    if isempty(expi)
        expi = find(strcmp([Trck.trackingdir,'jaaba/',exp],J.x.expDirNames));
    end
    
    if isempty(expi)
        report('W',['Experiment ',exp,' exist in labels file but not in jab file'])
        continue
    end
    
    Te = T(strcmp(T.experiment,exp),:);    
    
    labeled_ids = unique(Te.id);
    
    for i = 1:length(labeled_ids)
        
        id = labeled_ids{i};
        idi = find(strcmp(id,Trck.usedIDs));
        
        Ti = Te(strcmp(Te.id,id),:);
        
        labels(expi).flies(i,1) =  idi;
        labels(expi).off(i) =  0;
        labels(expi).timelinetimestamp{i} = struct;
        labels(expi).timestamp{i} = [];
        labels(expi).t0s{i} = [];
        labels(expi).t1s{i} = [];
        labels(expi).names{i} = {};
        
        for b=1:length(behaviors)
            labels(expi).timelinetimestamp{i}.(behaviors{b}) = now;
        end
        
        for j=1:size(Ti,1)
            
            labels(expi).t0s{i}(j) = Ti.fi(j);
            labels(expi).t1s{i}(j) = Ti.ff(j) + 1;
            labels(expi).names{i}{j} = Ti.label{j};
            labels(expi).timestamp{i}(j) = now;
            
        end
        
        [imp_t0,imp_t1] = calc_imp(labels(expi).t0s{i}, labels(expi).t1s{i});
        
        labels(expi).imp_t0s{i} = imp_t0;
        labels(expi).imp_t1s{i} = imp_t1;
        
    end
    
end


J.x.labels = labels;
save(jab,'-struct','J');

if nargout>0
    labels_out = labels;
end


function [imp_t0s, imp_t1s] = calc_imp(t0s, t1s)

imp_t0s = [];
imp_t1s = [];

for i=1:length(t1s)
   
    if ~ismember(t1s(i)-1,t0s)
       
        imp_t0s(end+1) = t0s(i);
        imp_t1s(end+1) = t1s(i);
        
    end
        
end






