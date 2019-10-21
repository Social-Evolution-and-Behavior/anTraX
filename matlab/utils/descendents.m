function des = descendents(G,s,depth)
% find the set of nodes in directed graph G that are
% descendents of node s with max distance depth


des = s;

for i=1:depth
   
    desi = arrayfun(@(x) successors(G,x),des,'UniformOutput',false);
    desi = cat(1,desi{:});
    des = [des;desi];
    des = unique(des);
    
end

des(des==s)=[];
des = sort(des);