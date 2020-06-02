function x = tonum(x)

if ischar(x)
    x = lower(x);
    x = str2num(x);
end

