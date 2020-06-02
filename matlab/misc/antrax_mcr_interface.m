function antrax_mcr_interface(command, varargin)


switch command
    
    case 'antrax'
        
        antrax(varargin{:});
        
    case 'graph_explorer'
        
        graph_explorer_app(varargin{:});
        
    case 'validate_tracking'
        
        validate_tracking(varargin{:});
        
    case 'validate_classifications'
        
        validate_classifications(varargin{:});

    case 'solve_single_movie'
        
        expdir = varargin{1};
        m = str2num(varargin{2});
        solve_single_movie(expdir, m, varargin{3:end});
    
    case 'track_single_movie'
        
        expdir = varargin{1};
        m = str2num(varargin{2});
        track_single_movie(expdir, m, varargin{3:end});
        
    case 'export_single_movie'
        
        expdir = varargin{1};
        m = str2num(varargin{2});
        export_single_movie(expdir, m, varargin{3:end});
        
    case 'link_across_movies'
        
        expdir = varargin{1};
        link_across_moives(expdir, 'reset', true);
        
    case 'solve_across_movies'
        
        expdir = varargin{1};
        g = str2num(varargin{2});
        solve_across_movies(expdir, g, varargin{3:end});
                
end