classdef antblobobj < handle &  matlab.mixin.SetGet
    
    
    properties
        
        LABEL
        dscale
        center = [0,0]
        trj tracklet
        blobID
    end
    
    properties (Dependent)
        
        Nblob
        rcentroid
        rarea
        perimeter
        maxv
        
    end
    
    properties (Transient)
        DATA
        images
        Trck trhandles
    end
    
    methods
        
        function ab = antblobobj(Trck)
            
            if nargin>0
                ab.dscale = Trck.get_param('geometry_rscale');
                ab.center = Trck.get_param('geometry_arenacenter');
                ab.Trck = Trck;
            end
            
            
        end
        
        function remove(ab,idx2remove)
            
            if ~any(idx2remove)
                return
            end
            
            idx2keep = ~idx2remove;
            ab.DATA = ab.DATA(idx2keep,:);
            
            newlabel = zeros(1,length(idx2keep));
            newlabel(idx2keep) = 1:nnz(idx2keep);
            newlabel = uint32([0,newlabel]);
            ab.LABEL = newlabel(ab.LABEL+1);
            
            
        end
        
        function filter(ab,fieldname,th)
            
            idx2remove = ab.DATA.(fieldname)<th;
            ab.remove(idx2remove);
          
        end
        
        function N = get.Nblob(ab)
            N = size(ab.DATA,1);
        end
        
        %function bid = get.blobID(ab)
        %    bid = 1:ab.Nblob;
        %end
        
        function ra = get.rarea(ab)
            ra = double(ab.DATA.AREA) * ab.dscale^2;
        end
        
        function rc = get.rcentroid(ab)
            rc = (double(ab.DATA.CENTROID) - repmat(ab.center,ab.Nblob,1)) * ab.dscale;
        end
        
        function p = get.perimeter(ab)
            p = double(ab.DATA.PERIMETER) * ab.dscale;
        end
        
        function mv = get.maxv(ab)
            for i=1:ab.Nblob
                Mi = ab.LABEL==i;
                mv(i,1)=max(ab.Trck.currfrm.Z1(Mi));
            end
        end
        
    end
    
end
