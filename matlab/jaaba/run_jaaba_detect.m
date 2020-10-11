function run_jaaba_detect(Trck,varargin)

p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles')||isfolder(x));
addParameter(p,'trackingdirname',[],@ischar);
addParameter(p,'movlist',[]);
addParameter(p,'movie',true, @islogical);
addParameter(p,'jaaba_path',[]);
addParameter(p,'antrax_path',[]);
addParameter(p,'jab',[],@ischar);

parse(p,Trck,varargin{:});

if ~isempty(p.Results.jaaba_path)
    addpath(genpath(p.Results.jaaba_path));
    rmpath(genpath([p.Results.jaaba_path,'/compiled']));
end

if ~isempty(p.Results.antrax_path)
    addpath([p.Results.antrax_path,'/matlab/jaaba']);
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
    
dirs = {};

jaabadir = [Trck.trackingdir,filesep,'jaaba'];

for m=movlist
    
   dirs{end+1} = [jaabadir,filesep,Trck.expname,'_',num2str(m)]; 
    
end

JAABADetect(dirs,'jabfiles',{p.Results.jab},'forcecompute',true);