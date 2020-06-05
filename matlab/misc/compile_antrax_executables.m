    function compile_antrax_executables

%%%
%%% script to compile antrax executables 
%%% to be run for every version release
%%%


x=strsplit(fileparts(which('track_batch')),filesep);
antraxdir = strjoin(x(1:end-2),filesep);
srcdir = [antraxdir,filesep,'matlab'];
bindir = [antraxdir,filesep,'bin',filesep];

prefix = ['antrax_',lower(computer),'_'];


if ~ismember(computer,{'MACI64','GLNXA64'})
    
    report('E','anTraX works only on Linux/OSX :-(')
    return
    
end

report('I','Compiling antrax executables:')

% compile the antrax main app
% report('I','    ...main antrax app')
% eval(['mcc -m antrax.mlapp  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'antrax'])

% compile autoids app
% report('I','    ...autoids app')
% eval(['mcc -m validate_classifications.mlapp  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'validate_classifications'])

% compile validation app
% report('I','    ...validation app')
% eval(['mcc -m validate_tracking.mlapp  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'validate_tracking'])

% compile graph explorer
% report('I','    ...graph explorer app')
% eval(['mcc -m graph_explorer_app.mlapp  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'graph_explorer_app'])

% new mcr interface
eval(['mcc -m antrax_mcr_interface.m  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'mcr_interface'])
% 
% % compile the track function
% report('I','    ...track function')
% eval(['mcc -m track_single_movie.m  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'track_single_movie'])
% 
% % compile the stitch function
% report('I','    ...stitch function')
% eval(['mcc -m link_across_movies.m  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'link_across_movies'])
% 
% % pair search function 
% % report('I','    ...pair search function')
% % eval(['mcc -m pair_search_single_movie.m  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'pair_search_single_movie'])
% 
% % compile the solve function
% report('I','    ...solve function')
% eval(['mcc -m solve_single_graph.m  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'solve_single_graph'])

% jaaba functions
% report('I','    ...jaaba functions')
% jaabadir = getenv('ANTRAX_JAABA_PATH');

% addpath(genpath(jaabadir));
% rmpath(genpath([jaabadir,filesep,'compiled']));

% eval(['mcc -m prepare_data_for_jaaba.m  -a ',srcdir,' -a ',[jaabadir,'perframe/params'],' -d ',bindir, ' -o ', prefix, 'prepare_data_for_jaaba'])
% eval(['mcc -m run_jaaba_detect.m  -a ',srcdir,' -a ',[jaabadir,'perframe/params'],' -d ',bindir, ' -o ', prefix, 'run_jaaba_detect'])
