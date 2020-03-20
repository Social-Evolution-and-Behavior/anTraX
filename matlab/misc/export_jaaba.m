function export_jaaba(Trck,varargin)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addParameter(p,'movlist',Trck.movlist,@isnumeric);
addParameter(p,'by','tracklet',@(x) ismember(x,{'tracklet','ant'}));
addParameter(p,'ntracklets',-1,@isnumeric);
addParameter(p,'movie',true,@islogical);
addParameter(p,'nframes',-1,@isnumeric);

parse(p,Trck,varargin{:});

jaabadir = [Trck.trackingdir,filesep,'jaaba'];
mkdirp(jaabadir);


for m=p.Results.movlist

    
    mjdir = [jaabadir,filesep,Trck.expname,'_',num2str(m),filesep];
    mkdirp(mjdir);
    
    % copy/link video
    if p.Results.movie
    
        movfile = Trck.er.movfile(1); 
        
        ext = strsplit(movfile,'.');
        ext = ext{end};
  
        system(['ln -s "',movfile,'" "',mjdir,'movie.',ext,'"']); 
        
%         if ismember(ext,{'avi','mov'})
%             system(['ln -s "',movfile,'" "',mjdir,'movie.',ext,'"']); 
%         else
%             outfile = [mjdir,filesep,'movie.mov'];
%             if ~exist(outfile,'file')
%                 system(['ffmpeg -i "',movfile,'" -vcodec copy "',mjdir,'movie.mov','"']); 
%             end
%         end
    
    end
  
    
    % create tracks file
  
    G = Trck.loaddata(m); 
    G.set_data;

    if strcmp(p.Results.by, 'tracklet')
        
        
        single_trjs = G.trjs(G.trjs.isSingle);
        
        if p.Results.ntracklets < 0
            ntracklets = length(single_trjs);
        else
            ntracklets = min(length(single_trjs), p.Results.ntracklets);
        end
        
        for i=1:ntracklets
            
            trj = single_trjs(i);
            
            trx(i).x = torow(trj.CX);
            trx(i).y = torow(trj.CY);
            trx(i).theta = torow(double(trj.ORIENT));
            trx(i).a = torow(trj.MAJAX)/4;
            trx(i).e = torow(trj.ECCENT);
            trx(i).b = trx(i).a.*sqrt(1-trx(i).e);
            trx(i).nframes = trj.len;
            trx(i).firstframe = trj.ti.mf;
            trx(i).endframe = trj.tf.mf;
            trx(i).off = trx(i).firstframe;
            trx(i).id = i;
            trx(i).x_mm = torow(trj.x)*1000;
            trx(i).y_mm = torow(trj.y)*1000;
            trx(i).theta_mm = trx(i).theta;
            trx(i).a_mm = trx(i).a * trj.dscale * 1000;
            trx(i).b_mm = trx(i).b * trj.dscale * 1000;
            trx(i).sex = 'F';
            trx(i).dt = torow(trj.dt(2:end));
            trx(i).fps = Trck.er.fps;
            
        end
    else
        
        
        for i=1:Trck.NIDs
           
            report('I',['Working on ',Trck.usedIDs{i}]);
            
            A = get_ant_data(Trck,'m',m,'id',Trck.usedIDs{i},'G',G,'inject_nans',true);
      
            trx(i).x = torow(A.CENTROID(:,1));
            trx(i).y = torow(A.CENTROID(:,2));
            trx(i).theta = torow(double(A.ORIENT));
            trx(i).blobarea = torow(double(A.AREA));
            trx(i).blobarea(~A.single) = nan;
            trx(i).a = torow(A.MAJAX)/4;
            trx(i).e = torow(A.ECCENT);
            trx(i).b = trx(i).a.*sqrt(1-trx(i).e);
            trx(i).nframes = size(A,1);
            trx(i).firstframe = 1;
            trx(i).endframe = Trck.er.movies_info(m).nframes;
            trx(i).off = trx(i).firstframe;
            trx(i).id = Trck.usedIDs{i};
            trx(i).x_mm = torow(trx(i).x)*1000;
            trx(i).y_mm = torow(trx(i).y)*1000;
            trx(i).theta_mm = trx(i).theta;
            trx(i).a_mm = trx(i).a * Trck.get_param('geometry_rscale') * 1000;
            trx(i).b_mm = trx(i).b * Trck.get_param('geometry_rscale') * 1000;
            trx(i).sex = 'F';
            trx(i).dt = torow(A.dt(2:end));
            trx(i).fps = Trck.er.fps;
                       
        end
    
        
    end
    
    save([mjdir,'trx.mat'],'trx');
    
end




end

