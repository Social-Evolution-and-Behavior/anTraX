function add_examples(trj,varargin)


if ~isscalar(trj)
    for i=1:length(trj)
        add_examples(trj(i),varargin{:});
    end
    return
end

Trck = trj.Trck;
p = inputParser;
addRequired(p,'trj',@(x) isa(x,'tracklet'));
addRequired(p,'id',@ischar);
addParameter(p,'tt','all');
addParameter(p,'classdir',[Trck.classdir,'classifier']);

% parse inputs
parse(p,trj,varargin{:});

if ~isfolder(p.Results.classdir)
    error('classdir does not exist')
end


target_dir = [p.Results.classdir,filesep,'examples',filesep,p.Results.id,filesep];

mkdirp(target_dir);

if ~isfolder(target_dir)
    error('Could not locate target dir')
end

tt = p.Results.tt;

if isnumeric(tt)
    tt = trtime(Trck,tt);
elseif ischar(tt) && strcmp(tt,'all')
    tt = trj.tt;
end

ims = trj.get_image(tt);
msk = repmat(max(ims,[],3)==0,[1,1,3,1]);
ims(msk)=255;

for i=1:size(ims,4)
    
    fname = [target_dir,Trck.expname,'.',trj.name,'.',num2str(tt(i).f),'.png'];
    imwrite(ims(:,:,:,i),fname);
    
end





