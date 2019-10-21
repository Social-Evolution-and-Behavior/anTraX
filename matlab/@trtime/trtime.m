classdef trtime < matlab.mixin.SetGet & matlab.mixin.CustomDisplay
    
    
    properties

        absframe
        realtime
        interval
        
    end
    
    properties (Dependent)
        
        movnum
        framenum
        
    end
    
    properties (Hidden,Transient)
        
        Trck 
        
    end
    
    properties (Dependent,Hidden)
        
        f
        m
        mf
        dt
        t
        
    end
    
    properties (Access=private)
        
        movies_fi
        movies_ff
        
    end
        
    methods
        
        function trt = trtime(arg0,arg1,arg2)
            
            if nargin==0
                return
            end
            
            if isa(arg0,'trhandles')
                Trck = arg0;
                movies_fi = [Trck.er.movies_info.fi];
                movies_ff = [Trck.er.movies_info.ff];
            elseif isa(arg0,'expreader')
                Trck = [];
                movies_fi = [arg0.movies_info.fi];
                movies_ff = [arg0.movies_info.ff];
            elseif isa(arg0,'trtime')
                Trck = [];
                movies_fi = arg0.movies_fi;
                movies_ff = arg0.movies_ff;
            end
            
            if nargin==1
                trt.Trck=Trck;
                trt.movies_fi = movies_fi;
                trt.movies_ff = movies_ff;
            elseif nargin>1
                m = size(arg1,1);
                n = size(arg1,2);
                trt(m,n) = trtime;
                for i=1:length(arg1)
                    trt(i).Trck=Trck;
                    trt(i).movies_fi = movies_fi;
                    trt(i).movies_ff = movies_ff;
                    if nargin==2
                        trt(i).absframe = arg1(i);
                        [trt(i).movnum,trt(i).framenum] = trt(i).get_m_mf(arg1(i));
                    else
                        trt(i).movnum = arg1(i);
                        trt(i).framenum = arg2(i);
                        trt(i).absframe = trt(i).get_f(arg1(i),arg2(i));
                    end
                end
            end
            
        end
        
        function c = plus(a,b)
            
            if ~isa(a,'trtime') || ~isnumeric(b) || ~rem(b,1) == 0
                error('Can only add trtime to whole numeric')
            end
                
            c = trtime(a(1),[a.f] + b);
            
        end
        
        function c = minus(a,b)
            
            if isa(a,'trtime') && isa(b,'trtime')
                c = [a.f] - [b.f];
            elseif isa(a,'trtime') && isnumeric(b)
                c = a + (-b);
            else
                error('Wrong argument types to trtime minus')
            end
            
        end

        function yes = eq(a,b)
            if ~isa(b,'trtime')
                yes = [a.f] == b;
            else
                yes = [a.f] == [b.f];
            end
        end
        
        function yes = ne(a,b)
            if ~isa(b,'trtime')
                yes = [a.f] ~= b;
            else
                yes = [a.f] ~= [b.f];
            end
        end
        
        function yes = lt(a,b)
            if ~isa(b,'trtime')
                yes = [a.f] < b;
            else
                yes = [a.f] < [b.f];
            end
        end
        
        function yes = gt(a,b)
            if ~isa(b,'trtime')
                yes = [a.f] > b;
            else
                yes = [a.f] > [b.f];
            end
        end
        
        function yes = le(a,b)
            if ~isa(b,'trtime')
                yes = [a.f] <= b;
            else
                yes = [a.f] <= [b.f];
            end
        end
        
        function yes = ge(a,b)
            if ~isa(b,'trtime')
                yes = [a.f] >= b;
            else
                yes = [a.f] >= [b.f];
            end
        end
        
        function tarray = colon(a,d,b)
            if nargin==2
                b=d;
                d=1;
            end
            tarray = trtime(a,a.f:d:b.f);
        end
        
        function [tmin,imin] = min(tarray)
            [~,imin] = min([tarray.f]);
            tmin = tarray(imin);
        end
        
        function [tmax,imax] = max(tarray)
            [~,imax] = max([tarray.f]);
            tmax = tarray(imax);
        end
        
        function [tarray,idx] = sort(tarray,varargin)
            
            idx = argsort([tarray.f],varargin{:});
            tarray = tarray(idx);
            
        end
        
        function m = get.movnum(trt)
            [m,~] = get_m_mf(trt,trt.f);
        end
        
        function mf = get.framenum(trt)
            [~,mf] = get_m_mf(trt,trt.f);
        end
        
        function set.movnum(~,~)
        end
        
        function set.framenum(~,~)
        end
        
        function f = get.f(trt)
            f = trt.absframe;
        end
        
        function m = get.m(trt)
            m = trt.movnum;
        end
        
        function mf = get.mf(trt)
            mf = trt.framenum;
        end
        
       
    end
    
    methods(Access = protected)
        
        function f = get_f(trt,m,mf)
            f = trt.movies_fi(m) + mf - 1;
        end
        
        function [m,mf] = get_m_mf(trt,f)
            m = find(f>=trt.movies_fi,1,'last');
            mf = f - trt.movies_fi(m) + 1;
        end
        
        
        function groups = getPropertyGroups(obj)
            if isscalar(obj)
                % Specify the values to be displayed for properties
                propList = struct('movnum',obj.m,...
                    'framenum',obj.mf,'absframe',obj.f);
                groups = matlab.mixin.util.PropertyGroup(propList);
            else 
                propList = {'movnum','framenum','absframe'};
                groups = matlab.mixin.util.PropertyGroup(propList);
            end
        end
    end
    
    methods (Static)
        
        function trt = loadobj(trt)
            
            if ~isempty(trt.Trck)
                trt=trtime(trt.Trck,trt.absframe);
            end
                
        end
        
    end
    
    
    
end