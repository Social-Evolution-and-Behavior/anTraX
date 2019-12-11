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
eval(['mcc -m track_single_movie.m  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'track_single_movie'])
eval(['mcc -m link_across_movies.m  -a ',srcdir,' -d ',bindir, ' -o ', prefix, 'link_across_movies'])

% compile the solve function
report('I','    ...solve function')

