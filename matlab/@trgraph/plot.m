function h = plot(G,varargin)
% plot a slice of a tracklet graph G between frame ti and frame tf

p = inputParser;

addRequired(p,'G',@(x) isa(x,'trgraph'));
addParameter(p,'fi',G.ti.f);
addParameter(p,'ff',G.ti.f+1000);
addParameter(p,'ax',[]);
addParameter(p,'timey',logical(0),@islogical);
addParameter(p,'nodesize',10);
addParameter(p,'id',[]);

parse(p,G,varargin{:});


fi = p.Results.fi;
ff = p.Results.ff;

if isempty(p.Results.ax)
    figure,
    ax = gca;
else
    ax = p.Results.ax;
end


% extract subgraph to plot
if ~isfield(G.aux,'fi')
    G.aux.fi = [G.trjs.fi];
    G.aux.ff = [G.trjs.ff];
end
node_fi = G.aux.fi;
node_ff = G.aux.ff;


include = find((node_ff >= fi) & (node_fi <=ff));
exclude = indegree(G.G,include)==0 & outdegree(G.G,include)==0 & torow(~any(G.possible_ids(include,:),2));
include = include(~exclude);

if isempty(include)
    report('E','slice contained no nodes')
    return
end

sg = subgraph(G.G,include);
try
    sg_assigned_ids = G.assigned_ids(include,:);
    sg_possible_ids = G.possible_ids(include,:);
catch
    sg_assigned_ids = false(length(include),:);
    sg_possible_ids = false(length(include),:);
end

% find first and last layer tracklet
sg_trjs = [sg.Nodes.trj];
first = find([sg_trjs.fi]<=fi);
last = find([sg_trjs.ff]>=ff);
both = intersect(first,last);
last = setdiff(last,both);

z = sg.numnodes;

nodey = tocol([sg_trjs.fi]);

nodey(first) = fi;

% create dummy nodes for singular nodes
for i=1:length(both)
    sg = addnode(sg,['dummy',num2str(i)]);
    sg = addedge(sg,sg.Nodes(both(i),:).Name,['dummy',num2str(i)],1);
    nodey = [nodey;fi];
end

dummies1 = tocol(z+1:sg.numnodes);

z = sg.numnodes;

% create dummy nodes for singular nodes
for i=1:length(last)
    sg = addnode(sg,['dummy2_',num2str(i)]);
    sg = addedge(sg,sg.Nodes(last(i),:).Name,['dummy2_',num2str(i)],1);
    nodey = [nodey;ff];
end

dummies2 = tocol(z+1:sg.numnodes);


% create the graph plot
% sg = graph(adjacency(sg)+transpose(adjacency(sg)));

h = plot(ax, sg,'Layout','layered','Sources',first,'Sinks',dummies2,'NodeLabel',[],'ArrowSize',0);

nodex = get(h,'XData');
nodex(dummies2) = nodex(last);

if p.Results.timey
    set(h,'XData',nodex,'YData',-nodey)
else
    set(h,'XData',nodex,'YData',get(h,'YData'))
end


highlight_none()

%labels = arrayfun(@(x) [num2str(x.index)]  ,[sg.Nodes.trj],'UniformOutput',false);
%labelnode(h,1:size(sg.Nodes,1),labels);


m = uimenu('Text','Highlight ID');
for i=1:length(G.usedIDs)
    mitem(i) = uimenu(m,'Text',G.usedIDs{i},'MenuSelectedFcn',{@highlight_id,i});
end
src_nodes = find(ismember({sg_trjs.propID},G.usedIDs));
%highlight(h,src_nodes,'Marker','x','NodeColor','m')






% modify data cursor
hdt = datacursormode;
hdt.UpdateFcn = @(obj,event_obj) GraphCursorCallback(obj,event_obj,sg,G,sg_assigned_ids,sg_possible_ids);

%c = uicontextmenu;
%m1 = uimenu(c,'Label','image','Callback',@image_tracklet_callback);

% create a highligh menu



% highligh first ID


% create context menu for nodes



    function highlight_none()
        

        highlight(h,sg,'LineWidth',2,'MarkerSize',p.Results.nodesize)
        
        markers = repmat({'o'},[1,sg.numnodes]);
        markers(dummies2) = {'none'};
        set(h,'Marker',markers);
        
        node_colors = repmat([0.6,0.6,0.6],[sg.numnodes,1]);
        edge_colors = repmat([0.6,0.6,0.6],[sg.numedges,1]);
        set(h,'NodeColor',node_colors,'EdgeColor',edge_colors);
        

    end


    function highlight_id(src,event,id)
        
        if nargin<3
            id=src;
        end
        
        if ischar(id)
            id = find(strcmp(id,G.usedIDs));
            
        end
        idstr = G.Trck.usedIDs{id};
        
        
        % remove all highlights        
        highlight_none;
        
        
        
        id_nodes = find(sg_possible_ids(:,id)|sg_assigned_ids(:,id));
        
        
        id_last = find(ismember(last,id_nodes));
        id_dummies = dummies2(id_last);
        
        id_nodes = cat(1,id_nodes,id_dummies);
        
        from = sg.Edges.EndNodes(:,1);
        to = sg.Edges.EndNodes(:,2);
        
        to_keep = ismember(from,sg.Nodes.Name(id_nodes)) & ismember(to,sg.Nodes.Name(id_nodes));
        
        idsg = rmedge(sg,find(~to_keep));
        
        
        pos_color = [0.5,0,0.5];
        ass_color = [0.2,0.2,0.8];
        src_color = [0.2,0.8,0.2];
        
        % possible nodes
        highlight(h,idsg,'EdgeColor',pos_color,'NodeColor',pos_color,'LineWidth',3,'MarkerSize',7);
        
        % assigned nodes
        assigned_nodes =  find(sg_assigned_ids(:,id));
        highlight(h,assigned_nodes,'NodeColor',ass_color,'MarkerSize',8);
        
        % source nodes
        idsrcnodes = src_nodes(strcmp(idstr,{sg_trjs(src_nodes).propID}));
        idsrcnodes = intersect(idsrcnodes,id_nodes);
        highlight(h,idsrcnodes,'NodeColor',src_color,'MarkerSize',8);
        
        
    end


end


function output_txt = GraphCursorCallback(obj,event_obj,sg,G,sg_assigned_ids,sg_possible_ids)
% Display the position of the data cursor
% obj          Currently not used (empty)
% event_obj    Handle to event object
% output_txt   Data cursor text (character vector or cell array of character vectors).

h = get(event_obj,'Target');
pos = get(event_obj,'Position');
ind = find(h.XData == pos(1) & h.YData == pos(2), 1);
trj = sg.Nodes.trj(ind);
name = sg.Nodes.Name{ind};
Gind = findnode(G.G,name);
assigned_ids = G.usedIDs(sg_assigned_ids(ind,:));
assigned_str = strjoin(assigned_ids,' ');
possible_ids = G.usedIDs(sg_possible_ids(ind,:));
possible_str = strjoin(possible_ids,' ');

output_txt = {['Index in plot: ' num2str(ind)], ...
    ['Index in G: ',num2str(Gind)],...
    ['Name: ' name],...
    ['from: ' num2str(trj.ti.m),'/',num2str(trj.ti.mf)],...
    ['to:   ' num2str(trj.tf.m),'/',num2str(trj.tf.mf)],...
    ['autoID: ' trj.autoID],...
    ['assigned: ',assigned_str],...
    ['possible: ',possible_str]};

end

%
% function image_tracklet_callback(src,cbdata)
% % Display the position of the data cursor
% % obj          Currently not used (empty)
% % event_obj    Handle to event object
% % output_txt   Data cursor text (character vector or cell array of character vectors).
%
% h = get(event_obj,'Target');
% pos = get(event_obj,'Position');
% ind = find(h.XData == pos(1) & h.YData == pos(2), 1);
% trj = src.G.Nodes.trj(ind);
% figure(100);
% image(trj);
% end
%
% end