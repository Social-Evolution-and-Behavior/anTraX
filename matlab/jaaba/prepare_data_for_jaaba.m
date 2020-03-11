function prepare_data_for_jaaba(Trck,varargin)

p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addParameter(p,'movlist',Trck.movlist,@isnumeric);
addParameter(p,'movie',true,@islogical);

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

for i=p.Results.movlist
    
    mjdir = [Trck.trackingdir,'jaaba/',Trck.expname,'_',num2str(i)];
    if isfolder([mjdir,filesep,'perframe'])
        rmdir([mjdir,filesep,'perframe'],'s');
    end
    mkdirp([mjdir,filesep,'perframe']);
    
    % compute JAABA-defined perframe features
    export_jaaba(Trck,'movlist',i,'by','ant','movie',p.Results.movie);
    compute_features_for_jaaba(Trck,i);
    JLD.AddExpDir(mjdir);
   
end


% add experiment list



