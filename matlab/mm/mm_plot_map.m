function mm_plot_map(embeddingValues)


if iscell(embeddingValues)
    embeddingValues = cat(1,embeddingValues{:});
end


embeddingValues = map(embeddingValues);

maxVal = max(abs(embeddingValues),[],'all');
maxVal = round(maxVal * 1.1);

sigma = maxVal / 40;
numPoints = 1001;
rangeVals = [-maxVal maxVal];

[xx,density] = findPointDensity(embeddingValues,sigma,numPoints,rangeVals);

figure
maxDensity = max(density(:));
imagesc(xx,xx,density)
axis equal tight off xy
caxis([0 maxDensity * .8])
colormap(jet)
colorbar



function X = map(X)

S = sign(X);
X = abs(X);

Y = X;
Y(X<10) = 1.5*X(X<10);
Y(X>=10) = X(X>=10) + 5;

X = Y.*S;