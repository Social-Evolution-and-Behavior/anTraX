function import_jaaba_results(Trck)


jdir = [Trck.trackingdir,'jaaba',filesep];



% get behaviors
behaviors = {};
for m = Trck.movlist
    
    mjdir = [jdir,Trck.expname,'_',num2str(m),filesep];
    
    if ~isfolder(mjdir)
        continue
    end
    scorefiles = dir([mjdir,'scores_*.mat']);
    scorefiles = {scorefiles.name};
    for i=1:length(scorefiles)
        b =  scorefiles{i}(8:end-4);
        behaviors{end+1} = b;
    end
    
end

behaviors = unique(behaviors);

report('I',['Import JAABA results from ',num2str(length(behaviors)),' behaviors']);

for m = Trck.movlist
    
    report('I',['Working on movie ',num2str(m)]);
    
    mjdir = [jdir,Trck.expname,'_',num2str(m)];
    
    for ib = 1:length(behaviors)
        
        b = behaviors{ib};
        scorefile = [mjdir,filesep,'scores_',b,'.mat'];
        
        if ~exist(scorefile,'file')
            continue
        end
        
        load(scorefile, 'allScores');
        
        S = table;
        
        for i=1:Trck.NIDs
           
            id = Trck.usedIDs{i};
            S.(id) = allScores.scores{i}';
            
        end
        
        writetable(S,[jdir,'scores_',b,'_',num2str(m),'.csv']);
        
    end
    
    
    
    
end