function clear_tracking_data(Trck,movlist,moviepart)


if nargin<3 || isempty(moviepart)
    suffix = '';
else
    suffix = ['_p',num2str(moviepart)];
end

for m=movlist
    
    imagesfile = [Trck.imagedir,'images_',num2str(m),suffix,'.mat'];
    datafile = [Trck.trackletdir,'trdata_',num2str(m),suffix,'.mat'];
    graphfile = [Trck.graphdir,'graph_',num2str(m),'_',num2str(m),suffix,'.mat'];
    trjsfile = [Trck.graphdir,'graph_',num2str(m),'_',num2str(m),suffix,'_trjs.mat'];
    singlesfile = [Trck.trackletdir,'singles_',num2str(m),suffix,'.mat'];
    
    if exist(imagesfile,'file')
        report('I',['Clearing previous tracklet images for movie #',num2str(m)])
        delete(imagesfile);
    end
    
    if exist(datafile,'file')
        report('I',['Clearing previous tracklet data for movie #',num2str(m)])
        delete(datafile);
    end
    
    if exist(graphfile,'file')
        report('I',['Clearing previous graph data for movie #',num2str(m)])
        delete(graphfile);
    end
    
    if exist(trjsfile,'file')
        delete(trjsfile);
    end
    
    if Trck.get_param('geometry_multi_colony')
        for i=1:Trck.Ncolonies
            graphfile = [Trck.graphdir,Trck.colony_labels{i},filesep,'graph_',num2str(m),'_',num2str(m),suffix,'.mat'];
            if exist(graphfile,'file')
                delete(graphfile)
            end
        end
    end
    
    if exist(singlesfile,'file')
        delete(singlesfile);
    end
    
end

file = [Trck.trackletdir,'singles_all.mat'];

if exist(file,'file')
    delete(file);
end