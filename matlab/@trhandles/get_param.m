function p = get_param(Trck,pname)



switch pname
    
    case 'thrsh_meanarea'
        a = Trck.get_param('thrsh_meanareamax');
        b = Trck.get_param('thrsh_meanareamin');
        p = (a+b)/2;
    case 'linking_ofconnectmin'
        
        % this is the ref value, for obir in the ref scale
        p0 = Trck.get_param('linking_ofconnectmin_0');
        
        % this is the ref ant size in mm2
        ant_size_ref = Trck.get_param('thrsh_meanareamin_0');
                
        % this is the current ant size
        ant_size = Trck.get_param('thrsh_meanarea');
        
        scale0 = Trck.get_param('geometry_scale0');
        scale1 = Trck.get_param('geometry_rscale');
        
        % this is the scaling factor
        sf = Trck.get_param('linking_scale_factor');
        p = p0 * sf * ant_size/ant_size_ref * (scale0/scale1)^2;
        
        
        %p = round(p0*(scale0/scale1)^2);
    case 'sqsz'
        sqsz = 2.5*sqrt(Trck.get_param('thrsh_meanareamax'))/Trck.get_param('geometry_rscale');
        p = 2*round(sqsz/2);
        
    case 'single_video_post_commands'
        
        p = Trck.prmtrs.(pname);
        if isempty(p)
            p = {};
        end
    case 'linking_method'
 
        p = Trck.prmtrs.linking_method;
        
        if isa(p,'char')
            p = eval(['@',p]);
            Trck.set_param('linking_method',p);
        end
        
    otherwise
        if isfield(Trck.prmtrs,pname)
            % first see if parameter is already set in Trck
            p = Trck.prmtrs.(pname);
        else
            % if not, look for it in defaults
            p = get_default_param(Trck,pname);
            Trck.set_param(pname,p);
        end

end




end


function p = get_default_param(Trck,pname)

    prmtrs = default_params(Trck);
    
    if isfield(prmtrs,pname)
        p = prmtrs.(pname);
    else
        report('E',['No value for parameter ',pname]);
        p = NaN;
        return
    end
    
end

