function compile_antrax_executables

%%%
%%% script to compile antrax executables 
%%% to be run for every version release
%%%

antraxdir = [fileparts(which('track_batch')),'/../../'];
srcdir = [antraxdir,filesep,'matlab',filesep,'tracking'];
bindir = [antraxdir,filesep,'bin',filesep];

prefix = ['antrax_',lower(computer),'_'];


if ~ismember(computer,{'MACI64','GLNXA64'})
    
    report('E','anTraX works only on Linux/OSX :-(')
    return
    
end

report('I','Compiling antrax executables:')

% compile the antrax main app
report('I','    ...main antrax app')
eval(['mcc -m antrax.mlapp  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'app'])

% compile validation app


% compile graph explorer


% compile autoid app


% compile the track function
report('I','    ...track function')
eval(['mcc -m track_batch.m  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'track_batch'])

% compile the solve function
report('I','    ...solve function')

if strcmp(computer,'GLNXA64')
    
    % compile the hpc track function (linux only)
    report('I','    ...hpc track function')
    eval(['mcc -m track_single_movie_on_cluster.m  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'hpc_track_single'])
    
    % compile the hpc solve function (linux only)
    report('I','    ...hpc solve function')
    eval(['mcc -m solve_single_graph_on_cluster.m  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'hpc_solve_single'])
    
else
    
    report('W', 'Not on Linux computer, skipping hpc functions')

end
