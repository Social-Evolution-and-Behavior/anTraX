function [hfig,clearedfig,newfig] = getFigure(tagfig,varargin)
% jonathan saragosti
% 12/05/16
% This function helps mananging figures by recycling already existng
% figures, using the tag 'tagfig' instead of creating new ones.
p = inputParser();

% define the figure tag
addRequired(p,'tagfig',@isstr)

% define window style (default is the current session window style
addOptional(p,'WindowStyle',[],@(x) ismember(x,{'normal','docked'}));

% clear figure if existing
addParameter(p,'clearfigure',true)

% full screen mode
addParameter(p,'fullscreen',false,@islogical)


% parse the inputs
parse(p,tagfig,varargin{:})

% intialize tags 
newfig =false;
clearedfig = false;

% 
% % % oldposition =[];

% the tagfig varibale must be a string
if ~isstr(tagfig)
    error('input variable must be a string')
end

% Find all the open figures
OpenFig = findall(0,'type','figure');
Fignum = [];
% Collect their tags
if ~isempty(OpenFig)
FigTags = cat(2,{OpenFig(:).Tag});
Fignum = find(strcmp(FigTags,tagfig));
end
% if there is already a figure with the requested tag; reuse it
if ~isempty(Fignum)
    hfig = figure(OpenFig(Fignum(1)));
% % %     oldposition = get(hfig,'Position')
    % if the clear figure is requested
    if p.Results.clearfigure
        % reset all its axes
        arrayfun(@(x) cla(x,'reset'),hfig.Children);        
        clearedfig = true;
    end
    
else
    % set the tag to the requested one
    hfig = figure('Tag',tagfig);
    newfig = true;
end

if isempty(p.Results.WindowStyle)
    % if it's not a new figure
    if ~newfig
        % get the figure's window style
        windowstyle = get(hfig,'WindowStyle');
    % if it's a new one
    else
        % get the default one
        windowstyle = get(0,'DefaultFigureWindowStyle');
    end
else
        % otehrwise get the one requested
        windowstyle = p.Results.WindowStyle;
end
% ste the window style
set(hfig,'WindowStyle',windowstyle);

% if the fullscreen is requested
if p.Results.fullscreen
    % if the figure is docked
    if strcmp(get(hfig,'WindowStyle'),'docked')
        % just give a warning
        warning('the full screen option is not available for docked figures. set ''WindowStyle'' to ''normal'' to allow full screen for this specific figure or use ''set(0,''DefaultFigureWindowStyle'',''normal'' to undosck all new figures')
    else      
        % put it in full screen
        set(hfig,'Units','normalized')
        set(hfig,'Position',[0 0 1 1])
    end
% % % else
% % %     % get the old position
% % %     if ~isempty(oldposition)
% % %         set(hfig,'Position',oldposition);
% % %     end
end

set(hfig,'Name',tagfig);