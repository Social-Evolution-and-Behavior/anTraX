function [trainingSetData,trainingSetAmps,projectionFiles] = runEmbeddingSubSampling(projectionDirectory,parameters)
%runEmbeddingSubSampling generates a training set given a set of .mat files
%
%   Input variables:
%
%       projectionDirectory -> directory path containing .mat projection 
%                               files.  Each of these files should contain
%                               an N x pcaModes variable, 'projections'
%       parameters -> struct containing non-default choices for parameters
%
%
%   Output variables:
%
%       trainingSetData -> normalized wavelet training set 
%                           (N x (pcaModes*numPeriods) )
%       trainingSetAmps -> Nx1 array of training set wavelet amplitudes
%       projectionFiles -> cell array of files in 'projectionDirectory'
%
%
% (C) Gordon J. Berman, 2014
%     Princeton University
    

    if nargin < 2
        parameters = [];
    end
    parameters = setRunParameters(parameters);
    
    setup_parpool(parameters.numProcessors)

    
    projectionFiles = findAllImagesInFolders(projectionDirectory,'.mat');
    
    N = parameters.trainingSetSize;
    L = length(projectionFiles);
    numPerDataSet = round(N/L);
    numModes = parameters.pcaModes;
    numPeriods = parameters.numPeriods;
     
    trainingSetData = zeros(numPerDataSet*L,numModes*numPeriods);
    trainingSetAmps = zeros(numPerDataSet*L,1);
    useIdx = true(numPerDataSet*L,1);
    
    for i=1:L
        
        fprintf(1,['Finding training set contributions from data set #' ...
            num2str(i) '\n']);
        
        currentIdx = (1:numPerDataSet) + (i-1)*numPerDataSet;
        
        [yData,signalData,signalAmps,~] = ...
                file_embeddingSubSampling(projectionFiles{i},parameters);
        
        DATA{i} = signalData(51:end-50,:);
        AMP{i} = signalAmps(51:end-50);
        %[trainingSetData(currentIdx,:),trainingSetAmps(currentIdx)] = ...
        %    findTemplatesFromData(signalData,yData,signalAmps,...
        %                        numPerDataSet,parameters);
            
        %a = sum(trainingSetData(currentIdx,:),2) == 0;
        %useIdx(currentIdx(a)) = false;
                                                        
    end
    
    %trainingSetData = trainingSetData(useIdx,:);
    %trainingSetAmps = trainingSetAmps(useIdx);
    
    trainingSetData = cat(1,DATA{:});
    trainingSetAmps = cat(2,AMP{:});
    
    % divide to groups of 5000
    n = size(trainingSetData,1);
    gs = ceil((1:n)/5000);
    
    if nnz(gs==max(gs))<4000
        gs(gs==max(gs))=max(gs)-1;
    end
 
    ng = max(gs);
    
    k = round(N/ng);
    parameters.relTol =  parameters.training_relTol;
    parameters.perplexity =  parameters.training_perplexity;
    for g=1:ng
       gdata = trainingSetData(gs==g,:);
       gamp = trainingSetAmps(gs==g);
       [D,~] = findKLDivergences(gdata);
       gy = tsne_d(D,parameters);
       [GDATA{g},GAMPS{g}] = ...
           findTemplatesFromData(gdata,gy,gamp,k,parameters);
    end
    
    
    trainingSetData = cat(1,GDATA{:});
    trainingSetAmps = cat(2,GAMPS{:});
    
%   
%     
%     idx = randperm(size(trainingSetData,1),N);
% 
%     trainingSetData = trainingSetData(idx,:);
%     trainingSetAmps = trainingSetAmps(idx);
%     
    
    if parameters.numProcessors > 1  && parameters.closeMatPool
        close_parpool
    end