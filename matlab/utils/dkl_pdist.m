function d = dkl_pdist(h1,h2)


for i=1:size(h2,1)
    
    for j=1:size(h1,1)
        
        d(j,i) = dkl(h1(i,:),h2(j,:));
        
    end
end




