function projections = find_PCA_projections(files,coeffs,meanValues,...
                            pixels,thetas,numProjections,scale,batchSize)
%find_PCA_projections finds the projection of a set of images onto
%postural eigenmodes (called by findProjections.m)
%
%   Input variables:
%
%       filePath -> cell array of VideoReader objects
%       coeffs -> postural eignmodes (L x (M<L) array)
%       meanValues -> mean value for each of the pixels
%       pixels -> radon-transform space pixels to use (Lx1 or 1xL array)
%       thetas -> angles used in Radon transform
%       numProjections -> # of projections to find
%       scale -> image scaling factor
%       batchSize -> # of files to process at once
%
%
%   Output variables:
%
%       projections -> N x d array of projection values
%
%
% (C) Gordon J. Berman, 2014
%     Princeton University

    if ~iscell(files)
        files = {files};
    end
    
    Nf = length(files);
    lengths = zeros(Nf,1);
    for i=1:Nf
        info = ffinfo(files{i});
        lengths(i) = info.nframes;
    end
    N = sum(lengths);
    
    L = length(pixels);
    
    if nargin < 6 || isempty(numProjections)
        numProjections = length(coeffs(1,:));
    end
    coeffs = coeffs(:,1:numProjections);
    
    
    testImage = read(VideoReader(files{1}),1);
    testImage = testImage(:,:,1);
    s = size(testImage);
    nX = round(s(1)/scale);
    nY = round(s(2)/scale);
    s = [nX nY];
    
    sM = size(meanValues);
    if sM(1) == 1
        meanValues = meanValues';
    end
    
    
    for t=1:Nf
    
        %fprintf(1,'Processing File #%5i out of %5i\n',t,Nf);
        
        M = lengths(t);
               
        currentVideoReader = VideoReader(files{t});
        
        tempData = zeros(M,L);
    
            
            for j=1:M
                
                a = read(currentVideoReader,j);
                a = double(imresize(a(:,:,1),s));
                lowVal = min(a(a>0));
                highVal = max(a(a>0));
                a = (a - lowVal) / (highVal - lowVal);
                
                R = radon(a,thetas);
                tempData(j,:) = R(pixels) - meanValues;
                
            end
            
            projections{t} = tempData*coeffs;
           
                            
    end
    
    projections = cat(1,projections{:});
    
    
    