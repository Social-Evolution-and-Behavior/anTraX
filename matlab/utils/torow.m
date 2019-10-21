function v = torow(v)

if isvector(v) && iscolumn(v)
    v = v';
end
