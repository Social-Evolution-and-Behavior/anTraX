classdef antdata < handle
    
    
    properties
        
        Trck trhandles
        expname
        antlist
        movlist
        data table
        
    end
    
    properties (Transient)
        
    end
    
    
    methods
        
        function ad = antdata(Trck, varargin)
            
            p = inputParser;
            
            addParameter(p,'antlist',Trck.usedIDs,@iscell);
            addParameter(p,'movlist',Trck.movlist,@isnumeric);
            parse(p,varargin{:});
            
            ad.expname = Trck.expname;
            ad.antlist = p.Results.antlist;
            ad.movlist = p.Results.movlist;
            
            ad.Trck = Trck;
            
            ad.load();
            
            
        end
        
        function load(ad)
            
            ad.data = table;
 
            for m=ad.movlist
                
                mdata = table;
                
                XY = ad.Trck.loadxy('movlist', m);
                
                mdata.f = tocol(ad.Trck.er.movies_info(m).fi:ad.Trck.er.movies_info(m).ff);
                
                for i=1:numel(ad.antlist)
                    
                    ant = ad.antlist{i};
                    
                    ant_data = table;
                    ant_data.x = XY.(ant)(:,1);
                    ant_data.y = XY.(ant)(:,2);
                    ant_data.or = XY.(ant)(:,3);
                    ant_data.type = XY.(ant)(:,4);
                                        
                    mdata.(ant) = ant_data;
                end
                
                ad.data = cat(1,ad.data, mdata);
                
            end
            
            
        end
        
        
       
        
    end
    
    
    
end