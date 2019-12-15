function link_across_movies(expdir,varargin)

p = inputParser();
addRequired(p,'expdir',@(x) (ischar(x) && isfolder(x)) || isa(x,'trhandles'));
addParameter(p,'trackingdirname',[]);
addParameter(p,'reset',false,@islogical);

parse(p,expdir,varargin{:});

Trck = trhandles.load(expdir,p.Results.trackingdirname);

links_file = [Trck.graphdir,'cross_movie_links.mat'];

if exist(links_file,'file') && ~p.Results.reset
    report('I','Link file exist, skipping')
    return
end

Trck.init_ba_obj;
Trck.init_of_obj;

link_blobs = Trck.get_param('linking_method');

costOfNonAssignment = 2; %(distance in pixels between 

%% link the tracklets across movies

Trck.set_er;

% find which movies are in this dataset
glist = Trck.graphlist;

cross_movie_links = struct('parent',{},'child',{});
% for each pair of successive movies
G2 = Trck.loaddata(glist(1),'all');

for i = 1:length(glist)-1
    
    m = glist(i);
    n = glist(i+1);
    G1 = G2;
    G2 = Trck.loaddata(n,'all');
    trjs1 = G1.trjs;
    trjs2 = G2.trjs;
    trjs = [trjs1;trjs2];
        
    % the first trtime is 
    trtimei= G1.tf;
    trtimef= G2.ti;
    
    if trtimef-trtimei~=1
        report('W','Frame gap between TRAJ files, skipping')
        continue
    end
    
    % get the trjobjs that end at the last frame of a movie or start at the
    % first frame
    trjs_i = trjs([trjs.tf]==trtimei);
    trjs_f = trjs([trjs.ti]==trtimef);
    
    if isempty(trjs_i) || isempty(trjs_f)
        report('W','No trajectories to link, skipping')
        continue
    end
    
    read_frame(Trck,trtimei);
    detect_blobs(Trck);
    read_frame(Trck,trtimef);
    detect_blobs(Trck);
    
    dt = Trck.currfrm.dat.tracking_dt;
    if dt>2.5*Trck.er.framerate
        report('W','large time gap between movies, skipping')
        continue
    end
    
    link_blobs(Trck);
    
    endpoints = cat(1,trjs_i.Cf);
    startpoints = cat(1,trjs_f.Ci);
    
    % compute all speeds for possible assignments
    cost_i = pdist2(endpoints,Trck.prevfrm.antblob.DATA.CENTROID,'euclidean');
    cost_f = pdist2(startpoints,Trck.currfrm.antblob.DATA.CENTROID,'euclidean');
    
    [assigmentsi,unassigned_trjsi,unassigned_blobsi] = assignDetectionsToTracks(cost_i,costOfNonAssignment);
    [assigmentsf,unassigned_trjsf,unassigned_blobsf] = assignDetectionsToTracks(cost_f,costOfNonAssignment);
    
    blobsi = assigmentsi(:,2);
    blobsf = assigmentsf(:,2);
    
    CAB = Trck.ConnectArraybin(blobsi,blobsf);
    trjs_i = trjs_i(assigmentsi(:,1));
    trjs_f = trjs_f(assigmentsf(:,1));
    
    for j=1:length(trjs_i)
        p = trjs_i(j);
        c = trjs_f(CAB(j,:));
        for k=1:length(c)
            %link(p,c(j));
            lnk.parent = p.name;
            lnk.child = c(k).name;
            cross_movie_links(end+1)=lnk;
        end
    end

    
end    


report('I',['Saving to file, total of ',num2str(length(cross_movie_links)),' links'])
save(links_file,'cross_movie_links');
report('G','Finished')

%        