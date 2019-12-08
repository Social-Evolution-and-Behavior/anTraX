function mm_export_trainset(Trck, varargin)


p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addParameter(p,'targetdir',[Trck.trackingdir,'mm']);
addParameter(p,'movlist',Trck.movlist);
addParameter(p,'minlength',500);
addParameter(p,'align',true)
addParameter(p,'colorsegment',true)
addParameter(p,'antsamples',2500)

parse(p,Trck,varargin{:});

movlist = torow(p.Results.movlist);
params.cm = repmat(tocol(linspace(0,1,256)),[1,3]);

mkdirp(p.Results.targetdir);
outdir = [p.Results.targetdir,filesep,'aligned'];
if isfolder(outdir)
    rmdir(outdir, 's');
end
mkdirp(outdir);

% load tracklet table
ttable = load_tracklet_table(Trck, movlist);
ttable = ttable(ttable.single==1,:);
ttable.len = ttable.to - ttable.from + 1;
ttable = ttable(ttable.len >= p.Results.minlength,:);

for i=1:length(Trck.usedIDs)
    
   atable = ttable(strcmp(ttable.ant,Trck.usedIDs{i}),:);
   atable = atable(randperm(size(atable,1)),:);
   clen = cumsum(atable.len);
   n = find(clen >= p.Results.antsamples, 1, 'first');
   atables{i} = atable(1:n,:);
   
end

ttable = cat(1,atables{:});
ttable = ttable(argsort(ttable.m),:);

writetable(ttable, [p.Results.targetdir,filesep,'ttable.csv']);


report('I',['Exporting total of ',num2str(size(ttable,1)),' tracklets'])

for m=torow(unique(ttable.m))
    
    report('I',['Exporting clips from movie ',num2str(m)]); 
    tracklets = ttable.tracklet(ttable.m==m);
    images = load([Trck.imagedir,'images_',num2str(m),'.mat'],tracklets{:});

    for i=1:length(tracklets)
        
        ims = images.(tracklets{i});
        sz = size(ims);
        
        if ~p.Results.colorsegment
            
            ims = double(ims)/255;
            ims = min(ims,[],3);
            
            ims(ims==0)=1;
            ims = ims * 1/0.6 - 1/6;
            ims(ims<0)=0;
            ims(ims>1)=1;
            
            ims = repmat(ims,[1,1,3,1]);
            
        else
                           
            ims = mm_color_segmentation(ims, params);
            
        end
        
        if p.Results.align
                                    
            ims = mm_align(ims, params);
      
        end
        

        if max(ims(1,:,:,:),[],'all')>0.5 || max(ims(end,:,:,:),[],'all')>0.5 || max(ims(:,1,:,:),[],'all')>0.5 || max(ims(:,end,:,:),[],'all')>0.5
        
            continue
            
        end
            
        mov = immovie(uint8(ims*256),params.cm);
        vw = VideoWriter([outdir,filesep,tracklets{i},'.avi']);
        open(vw);
        vw.writeVideo(mov);
        close(vw);
        
    end
    
    
    
end



