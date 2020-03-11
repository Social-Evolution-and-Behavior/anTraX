function A = get_ant_data(Trck,varargin)

p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addParameter(p,'m',Trck.movlist(1),@isnumeric);
addParameter(p,'inject_nans',false,@islogical);
addParameter(p,'id',Trck.usedIDs{1},@(x) ismember(x,Trck.usedIDs));
addParameter(p,'G',[]);

parse(p,Trck,varargin{:});


m = p.Results.m;
id = p.Results.id;

if ~isempty(p.Results.G)
    G = p.Results.G;
else
    G = Trck.loaddata(m);
end


T = readtable([Trck.trackingdir,'antdata',filesep,'tracklets_table_',num2str(m),'_',num2str(m),'.csv']);
T = T(strcmp(T.ant,id),:);


A = table;
nframes = length(Trck.er.movies_info(m).fi:Trck.er.movies_info(m).ff);
A.frame = tocol(Trck.er.movies_info(m).fi:Trck.er.movies_info(m).ff);
A.dt = ones(size(A.frame))/Trck.er.fps;
A.CENTROID = nan(nframes,2);
A.AREA = nan(nframes,1);
A.MAJAX = nan(nframes,1);
A.ECCENT = nan(nframes,1);
A.ORIENT = nan(nframes,1);
A.single = false(nframes,1);


for i=1:size(T,1)
    
    trj = G.trjs.withName(T.tracklet{i});
    ix = trj.ti.mf:trj.tf.mf;
    A.CENTROID(ix,:) = trj.data_.CENTROID;
    A.dt(ix,:) = trj.data_.dt;
    A.single(ix,:) = true;
    
    if T.single(i)==1
        
        A.AREA(ix,:) = trj.data_.AREA;
        A.MAJAX(ix,:) = trj.data_.MAJAX;
        A.ECCENT(ix,:) = trj.data_.ECCENT;
        A.ORIENT(ix,:) = trj.data_.ORIENT;
        
    else
        
        if p.Results.inject_nans
            A.CENTROID(ix(1),:) = nan;
            A.CENTROID(ix(end),:) = nan;
        end
        
    end
    
    
end


