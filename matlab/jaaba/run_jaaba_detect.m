function run_jaaba_detect(Trck,varargin)


p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addParameter(p,'movlist',Trck.movlist);
addParameter(p,'jabs',{},@iscell);

parse(p,Trck,varargin{:});

dirs = {};

jaabadir = [Trck.trackingdir,filesep,'jaaba'];

for m=p.Results.movlist
    
   dirs{end+1} = [jaabadir,filesep,Trck.expname,'_',num2str(m)]; 
    
end

JAABADetect(dirs,'jabfiles',p.Results.jabs,'forcecompute',true);