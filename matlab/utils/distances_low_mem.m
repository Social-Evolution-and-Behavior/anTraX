function D = distances_low_mem(G)


% skip noant nodes

% skip unconnected ndoes


N = size(G.Nodes,1);
n = 3000;
D = sparse(N,N);


for i=1:ceil(N/n)
    
    i1 = (i-1)*n+1;
    i2 = min(i*n+n/2,N);
    d = distances(G,i1:i2,i1:i2,'Method','unweighted');
    d(isinf(d)) = 0;
    d = max(cat(3,uint8(d),full(D(i1:i2,i1:i2))),[],3);
    D(i1:i2,i1:i2) = d; 
    
end