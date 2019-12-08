classdef antdata 
    
    
    properties
        
        expname
        ids
        data table
        
    end
    
    

    methods
        
        function ad = antdata(varargin)
            
            p = inputParser;
            
            addParameter(p,'ids',{},@iscell);
            addParameter(p,'frames',[],@isnumeric);
            addParameter(p,'fields',{'x','y','or','tracklet','type'},@iscell);
            addParameter(p,'dbfile',[],@ischar);
            parse(p,varargin{:});
            
            
            ad.ids = p.Results.ids;
            
%             ad.data = table([],'VariableNames',{'frame'});
%             
%             % create the data table
%             for i=1:length(ad.ids)
%                 
%                 T = table;
%                 for j=1:length(p.Results.fields)
%                     T.(p.Results.fields{j})=zeros(0);
%                 end
%                 
%                 ad.data.(ad.ids{i}) = T;
%             end
            
        end
        
        
        function add_ant(ad, id)
           
          
            
        end
        
%         
%         function save(ad, filename)
%             
%             data = ad.data;
%             ids = ad.ids;
%             fields = ad.data.(ad.data.Properties.VariableNames{2}).Properties.VariableNames;
%             
%             wsize=65;
%             
%             for i=1:length(ids)
%                 
%                 for j=1:length(fields)
%                     
%                     
%                     h5create(filename,'/
%                     
%                 end
%                 
%                 
%             end
%             
%             
%             h5create(db,'/data',[Inf wsize wsize 3],
%             'ChunkSize',[1 wsize wsize 3],'Datatype','single', 'Deflate',9 ,'Shuffle',true);
%             
%             h5create(db,'/label',[Inf 1],
%             'ChunkSize',[1 1],'Datatype','single', 'Deflate',9 ,'Shuffle',true);
%             
%             h5create(db,'/mean',[65 65 3]);
%             
%             
%             save(filename,'data','ids','fields');
%             
%         end
        
        
        
    end
    
    
    
end