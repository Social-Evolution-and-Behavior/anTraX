function out = tagged_figure(tag)

% if figure with tag exist, return its handle, otherwise, create a new one

if ~ischar(tag)
    report('E','input variable must be a string')
    return
end

% Find all the open figures
figs = findall(0,'type','figure');

if ~isempty(figs)
    tags = {figs.Tag};
else
    tags = {};
end

target = find(strcmp(tag,tags));

if length(target)>1
    report('W','More than one fig with tag exist')
end

if isempty(target)
    
    hfig = figure;
    set(hfig,'Name',tag,'Tag',tag);
    
else
    
    hfig = figs(target(1));
    
end

if nargout>0
    out = hfig;
end
