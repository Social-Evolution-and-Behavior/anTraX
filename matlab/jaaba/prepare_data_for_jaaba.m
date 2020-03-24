function prepare_data_for_jaaba(Trck,varargin)

p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addParameter(p,'movlist',Trck.movlist,@isnumeric);
addParameter(p,'movie',true, @islogical);
addParameter(p,'nw',1,@isnumeric);


parse(p,Trck,varargin{:});


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
movlist = p.Results.movlist;

for i=1:length(movlist)
    
    m = movlist(i);
    
    mjdir = [jaabadir,expname,'_',num2str(m)];
    if isfolder([mjdir,filesep,'perframe'])
        rmdir([mjdir,filesep,'perframe'],'s');
    end
    mkdirp([mjdir,filesep,'perframe']);
    % compute JAABA-defined perframe features
    export_jaaba(p.Results.Trck,'movlist',m,'by','ant','movie',p.Results.movie);
    compute_features_for_jaaba(p.Results.Trck,m);
    JLD.AddExpDir(mjdir);
   
end


% add experiment list



