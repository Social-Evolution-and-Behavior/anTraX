function setObjectsVal(hObjects,propertyName,value,varargin)
% jonathan saragosti
% 02/10/16
% this function sets all the object in the array of handles hObjects
% and that have the property 'propertyName' set to 'value'

% One can find these controls by looking for object with a given property
% set to a certain value:
%
% hObjects = findobj(GuiData.hfig, 'Enable','on');


p = inputParser();
% first argument is a figure
addRequired(p,'hControls');

% second argument is a property name
addRequired(p,'propertyName',@isstr);

% second argument is a property name
addRequired(p,'value');

% Except some of them
addOptional(p,'except',{},@iscellstr)


parse(p,hObjects,propertyName,value,varargin{:});

% make panel inactive    
for ncontrol = 1:length(hObjects)
    if ~ismember(hObjects(ncontrol).Tag,p.Results.except)
        set(hObjects(ncontrol),p.Results.propertyName,p.Results.value);
    end
end