function filter_frames(Trck,movlist)


for i=1:length(movlist)
    
    
    clear passed
    clear score
    
    G = loaddata(Trck,movlist(i));
    G.set_data
    
    single = G.trjs(G.trjs.isSingle('criteria','maxarea'));
    
    report('I',['Filtering frames for ',num2str(length(single)),' tracklets'])
    
    
    for j=1:length(single)
        
        if ~rem(j,1000)
            report('I',['   ... ',num2str(j),'/',num2str(length(single))])
        end
                
        trj = single(j);
        
        [p,s] = filter_frames(trj);
        passed.(trj.name) = p;
        score.(trj.name) = s;
        
    end
    
    clear G
    
    save([Trck.imagedir,'frame_passed_',num2str(movlist(i)),'.mat'],'-struct','passed','-v7.3');
    save([Trck.imagedir,'frame_score_',num2str(movlist(i)),'.mat'],'-struct','score','-v7.3');
end






