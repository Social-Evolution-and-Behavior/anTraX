function ids = all_possible_ids(colors)


ids = {};

for i=1:length(colors)
    for j=1:length(colors)
        ids{end+1} = [colors{i},colors{j}];
    end
end

ids = torow(ids);