function groups = divide2groups(N,ngroups)


a = floor(N/ngroups);
b = rem(N,ngroups);

groups={};

for i=1:b
    groups{i} = (i-1)*(a+1)+1:i*(a+1);
end

if length(groups)>0
    c = groups{end}(end);
else
    c = 0;
end

for i=b+1:ngroups
    groups{i} = c + [(i-1-b)*a+1:(i-b)*a];
end