function mm_train(Trck, varargin)


p = inputParser;

addRequired(p,'Trck',@(x) isa(x,'trhandles'));
addParameter(p,'pixels',true, @islogical);
addParameter(p,'pca',true,@islogical);
addParameter(p,'projections',true,@islogical);
addParameter(p,'train',true,@islogical);
addParameter(p,'embed',true,@islogical);
addParameter(p,'plot',true,@islogical);

parse(p,Trck,varargin{:});

mmdir = [Trck.trackingdir,filesep,'mm',filesep];
avidir = [mmdir,filesep,'aligned',filesep];

% find all avi files 
avilist = findAllImagesInFolders([mmdir,'aligned'],'.avi');
L = length(avilist);
numZeros = ceil(log10(L+1e-10));
disp(['Found ',num2str(L),' video files for training']);

%define any desired parameter changes here
parameters.numProcessors = 4;
parameters.maxF = 5;
parameters.minF = 0.2;
parameters.samplingFreq = 10;
parameters.trainingSetSize = 35000;
parameters.minArea = 500;

%initialize parameters
parameters = setRunParameters(parameters);

save([mmdir,'parameters.mat'],'parameters')

setup_parpool(parameters.numProcessors)

%% Find image subset statistics (a gui will pop-up here)

if p.Results.pixels
    fprintf(1,'Finding Subset Statistics\n');
    numToTest = parameters.pca_batchSize;
    [pixels,thetas,means,stDevs,~] = findRadonPixels(avidir,numToTest,parameters);
    save([mmdir,'RadonPixels.mat'],'pixels','thetas','means','stDevs')
else
    load([mmdir,'RadonPixels.mat'],'pixels','thetas','means','stDevs')
end

%% Find postural eigenmodes

if p.Results.pca
    fprintf(1,'Finding Postural Eigenmodes\n');
    [vecs,vals,meanValues] = findPosturalEigenmodes(avilist,pixels,parameters);
    
    vecs = vecs(:,1:parameters.numProjections);
    
    figure
    makeMultiComponentPlot_radon_fromVecs(vecs(:,1:25),25,thetas,pixels,[171 90]);
    caxis([-3e-3 3e-3])
    colorbar
    title('First 25 Postural Eigenmodes','fontsize',14,'fontweight','bold');
    drawnow;
    
    save([mmdir,'Eigenmodes.mat'],'vecs','vals','meanValues')
else
    load([mmdir,'Eigenmodes.mat'],'vecs','vals','meanValues')
end

%% Find projections for each data set

projdir = [mmdir,'projections',filesep];

if p.Results.projections



if isfolder(projdir)
    rmdir(projdir,'s')
end
mkdirp(projdir);
    
        
    fprintf(1,'Finding Projections\n');
    
    for i=1:L
        
        fprintf(1,'\t Finding Projections for File #%4i out of %4i\n',i,L);
        projections = findProjections(avilist{i},vecs,meanValues,pixels,parameters);
        
        fileNum = [repmat('0',1,numZeros-length(num2str(i))) num2str(i)];
        fileName = avilist{i};
        
        save_projections([projdir 'projections_' fileNum '.mat'],projections,fileName);
        
    end
    
end

%% Use subsampled t-SNE to find training set 

if p.Results.train
    fprintf(1,'Finding Training Set\n');
    [trainingSetData,trainingSetAmps,projectionFiles] = ...
        runEmbeddingSubSampling(projdir,parameters);
    
    %% Run t-SNE on training set
    
    
    fprintf(1,'Finding t-SNE Embedding for the Training Set\n');
    [trainingEmbedding,betas,P,errors] = run_tSne(trainingSetData,parameters);
    
    save([mmdir,'mapping.mat'],'trainingSetData','trainingSetAmps','projectionFiles','trainingEmbedding','betas','P','errors');
else
    load([mmdir,'mapping.mat'],'trainingSetData','trainingSetAmps','projectionFiles','trainingEmbedding','betas','P','errors');
end

%% Find Embeddings for each file


if p.Results.embed
    
    fprintf(1,'Finding t-SNE Embedding for each file\n');
    embeddingValues = cell(L,1);
    
    for i=1:L
        
        fprintf(1,'\t Finding Embbeddings for File #%4i out of %4i\n',i,L);
        
        load(projectionFiles{i},'projections');
        projections = projections(:,1:parameters.pcaModes);
        
        [embeddingValues{i},~] = ...
            findEmbeddings(projections,trainingSetData,trainingEmbedding,parameters);
        
        clear projections
        
        save([mmdir,'trainset_embeddings.mat'],'embeddingValues');
        
    end
    
else
    
    load([mmdir,'trainset_embeddings.mat'],'embeddingValues');
    
end



%% Make density plots

if p.Results.plot
    maxVal = max(max(abs(combineCells(embeddingValues))));
    maxVal = round(maxVal * 1.1);
    
    sigma = maxVal / 40;
    numPoints = 501;
    rangeVals = [-maxVal maxVal];
    
    [xx,density] = findPointDensity(combineCells(embeddingValues),sigma,numPoints,rangeVals);
    
    figure
    maxDensity = max(density(:));
    imagesc(xx,xx,density)
    axis equal tight off xy
    caxis([0 maxDensity * .8])
    colormap(jet)
    colorbar
    
end

close_parpool

