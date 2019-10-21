function expdirs = find_expdirs(root,init_only)


if nargin<2
    init_only=true;
end

if ~init_only
    report('E','Not yet implemented')
end

if is_expdir(root,init_only)
    expdirs = {root};
else
    sd = subdirs(root);
    expdirs={};
    for i=1:length(sd)
        expdirsi = find_expdirs([root,filesep,sd{i}],init_only);
        expdirs = [expdirs,expdirsi];
    end
end


% 

function sd = subdirs(d)

a = dir(d);
a = a([a.isdir]);
a = a(~strcmp({a.name},'.'));
a = a(~strcmp({a.name},'..'));

sd = {a.name};




