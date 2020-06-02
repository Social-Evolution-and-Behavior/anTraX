function prepare_data_for_jaaba(Trck,varargin)

p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles')||isfolder(x));
addParameter(p,'trackingdirname',[],@ischar);
addParameter(p,'movlist',[]);
addParameter(p,'jaaba_path',[]);
addParameter(p,'movie',true, @islogical);

parse(p,Trck,varargin{:});

if ~isempty(p.Results.jaaba_path)
    addpath(genpath(JAABA_PATH));
    rmpath(genpath([JAABA_PATH,'/compiled']));
end

if ischar(Trck) 
    Trck = trhandles(Trck,p.Results.trackingdirname);
end

movlist = p.Results.movlist;
if isempty(movlist)
    movlist = Trck.movlist;
elseif ischar(movlist)
    movlist = str2num(movlist);
end
    
    

% create an empty JLabelData object 
clear JLD
JLD=JLabelData('isInteractive',false);

% apply config file

macguf = Macguffin('antrax_obiroi');
macguf.behaviors.names = {'something','None'};
macguf.file.moviefilename = 'movie.mov';
macguf.file.trxfilename = 'trx.mat';
macguf.file.scorefilename = {'something_scores.mat'};

JLD.newJabFile(macguf);

jaabadir = [Trck.trackingdir,'jaaba',filesep];
expname = Trck.expname;

for i=1:length(movlist)
    
    m = movlist(i);
    
    mjdir = [jaabadir,expname,'_',num2str(m)];
    if isfolder([mjdir,filesep,'perframe'])
        rmdir([mjdir,filesep,'perframe'],'s');
    end
    mkdirp([mjdir,filesep,'perframe']);
    % compute JAABA-defined perframe features
    export_jaaba(Trck,'movlist',m,'by','ant','movie',p.Results.movie);
    compute_features_for_jaaba(Trck,m);
    JLD.AddExpDir(mjdir);
   
end


% add experiment list



