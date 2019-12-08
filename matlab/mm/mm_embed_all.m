function mm_embed_all(Trck,varargin)


p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addParameter(p,'movlist',Trck.movlist,@isnumeric);
addParameter(p,'minlength',150);
addParameter(p,'report',1000);

parse(p,Trck,varargin{:});

mmdir = [Trck.trackingdir,'mm',filesep];
outdir = [mmdir, 'embeddings',filesep];
mkdirp(outdir);

% load mm parameters
load([mmdir,'parameters.mat'],'parameters');
params = parameters;
load([mmdir,'RadonPixels.mat'],'pixels');
load([mmdir,'Eigenmodes.mat'],'vecs','meanValues');
load([mmdir,'mapping.mat'],'trainingSetData','trainingEmbedding');

for m=p.Results.movlist
    
    report('I',['Embedding tracklets from movie ',num2str(m)]); 
    
    % load tracklet table
    ttable = load_tracklet_table(Trck,m);
    
    % filter
    ttable = ttable(ttable.single==1,:);
    ttable.len = ttable.to - ttable.from + 1;
    ttable = ttable(ttable.len >= p.Results.minlength,:);
    ttable = ttable(ismember(ttable.ant,Trck.usedIDs),:);
    
    report('I',['     found ',num2str(size(ttable,1)), ' tracklets to embed']);
    
    % load images
    tracklets = ttable.tracklet(ttable.m==m);
    images = load([Trck.imagedir,'images_',num2str(m),'.mat'],tracklets{:});
    
    report('I',['     finished loading images']);
    
    for i=1:length(tracklets)
        
        if ~rem(i,p.Results.report)
            report('I',['     finished embedding ',num2str(i),'/',num2str(length(tracklets)),' tracklets'])
        end
        
        t = tracklets{i};
        
        % segment and align
        ims = images.(t);
        ims = mm_color_segmentation(ims, params);
        ims = mm_align(ims, params);
   
        % project
        projections = project_images(ims,vecs,meanValues,pixels,params);
            
        % embed
        projections = projections(:,1:params.pcaModes);
        
        [embeddings.(t),~] = ...
            findEmbeddings(projections,trainingSetData,trainingEmbedding,params);
        
        
    end
    
    % save
    save([outdir,'embeddings_',num2str(m),'.mat'],'-struct','embeddings');
    clear embeddings
    
end


end

function projections = project_images(ims, vecs, meanValues, pixels, params)


sz = size(ims);

if length(sz)<4
    sz(end+1:4) = 1;
end

numThetas = params.num_Radon_Thetas;
spacing = 180/numThetas;
thetas = linspace(0,180-spacing,numThetas);
scale = params.rescaleSize;
numProjections = params.numProjections;

coeffs = vecs(:,1:numProjections);


M = sz(4);

L = length(pixels);
        
nX = round(sz(1)/scale);
nY = round(sz(2)/scale);
s = [nX nY];
    
sM = size(meanValues);
if sM(1) == 1
    meanValues = meanValues';
end
    

tempData = zeros(M,L);


for j=1:M
    
    a = ims(:,:,1,j);
    a = double(imresize(a(:,:,1),s));
    lowVal = min(a(a>0));
    highVal = max(a(a>0));
    a = (a - lowVal) / (highVal - lowVal);
    
    R = radon(a,thetas);
    tempData(j,:) = R(pixels) - meanValues;
    
end

projections = tempData*coeffs;


end







