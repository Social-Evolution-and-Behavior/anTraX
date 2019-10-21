classdef angle < double
    
    methods
        
        function phi = angle(x)
            % assuming x is an angle, store the equivalent angle in
            % [-pi,pi)
            if nargin == 0
                x = double(0);
            end
            x = mod(x+pi,2*pi)-pi;
            phi = phi@double(x);
        end
       
        function c = plus(a,b)
            c = angle(plus@double(a,b));
        end
        
        function c = minus(a,b)
            c = angle(minus@double(a,b));
        end
        
        function c = uminus(a)
            c = angle(uminus@double(a));
        end
        
        function b = abs(a)
            b = angle(abs@double(a));
        end
        
        function d = diff(a)
            d = a(2:end)-a(1:end-1);
        end
        
        function inDeg = deg(a)
            inDeg = rad2deg(a);
        end
        
        function obj = subsasgn(obj,s,b)
         switch s(1).type
            case '()'
               d = double(obj);
               newd = builtin('subsasgn',d,s(1),b);
               obj = angle(newd);
            case '{}'
               error('Not a supported indexing expression')
            case '.'
               error('Not a supported indexing expression')
         end
      end
        
    end
    

end