function [I, A, g] = interaction_graph(XY, dthresh)

if nargin<2
    dthresh=0.002;
end

ants = fieldnames(XY);
nants = length(ants);

I = zeros(nants);
A = zeros(nants,1);

X = [];
Y = [];

NEST = [];
DNEST = [];

for i=1:nants
    
    X(:,i) = XY.(ants{i})(:,1);
    Y(:,i) = XY.(ants{i})(:,2);
    
end


NEST(:,1) = movmedian(median(X,2,'omitnan'),12001,'omitnan');
NEST(:,2) = movmedian(median(Y,2,'omitnan'),12001,'omitnan');

for i=1:nants
    
    DNEST(:,i) = sqrt(sum((XY.(ants{i})(:,1:2)-NEST).^2,2));
    
end

OUT = DNEST > 0.01;
OUT(isnan(OUT)) = false;

for i=1:nants
    xyi = XY.(ants{i})(:,1:2);
    A(i) = sum(sqrt(sum(diff(xyi).^2,2)),'omitnan');
    outi = OUT(:,i);
    for j=i+1:nants
        xyj = XY.(ants{j})(:,1:2);
        outj = OUT(:,j);
        d = sqrt(sum((xyi-xyj).^2,2));
        interacting = (d < dthresh) & outj & outi;
        I(i,j) = mean(interacting(outi & outj),'omitnan');
        I(j,i) = I(i,j);
    end
end

g=graph(I,'omitselfloops');
LWidths = 5*g.Edges.Weight/max(g.Edges.Weight);
MSizes = 20*A/max(A);

plot(g,'LineWidth',LWidths,'MarkerSize',5+MSizes,'NodeLabel',ants,'Layout','force','WeightEffect','inverse');