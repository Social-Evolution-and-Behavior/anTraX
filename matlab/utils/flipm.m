function A = flipm(A,dims)

for i=1:length(dims)
    A = flip(A,dims(i));
end

