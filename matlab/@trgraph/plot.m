function h = plot(G,fi,ff)
% plot a slice of a tracklet graph G between frame ti and frame tf

% extract subgraph to plot
if ~isfield(G.aux,'fi')
    G.aux.fi = [G.trjs.fi];
    G.aux.ff = [G.trjs.ff];
end
node_fi = G.aux.fi;
node_ff = G.aux.ff;

if nargin<3
    ff = max(node_ff);
end

if nargin<2
    fi = min(node_fi);
end

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

% create dummy nodes for singular nodes
for i=1:length(both)
    sg = addnode(sg,['dummy',num2str(i)]);
    sg = addedge(sg,sg.Nodes(both(i),:).Name,['dummy',num2str(i)],1);
    nodey = [nodey;max(nodey)];
end



dummies = tocol(z+1:sg.numnodes);

% create the graph plot
h = plot(sg,'Layout','layered','Sources',first,'Sinks',[tocol(last);dummies],'NodeLabel',[]);
nodex = get(h,'XData');
%set(h,'XData',nodex,'YData',-nodey)


%labels = arrayfun(@(x) [num2str(x.index)]  ,[sg.Nodes.trj],'UniformOutput',false);
%labelnode(h,1:size(sg.Nodes,1),labels);


m = uimenu('Text','Highlight ID');
for i=1:length(G.usedIDs)
    mitem(i) = uimenu(m,'Text',G.usedIDs{i},'MenuSelectedFcn',{@highlight_id,i});
end
src_nodes = find(ismember({sg_trjs.autoID},G.usedIDs));
%highlight(h,src_nodes,'Marker','x','NodeColor','m')






% modify data cursor
hdt = datacursormode;
hdt.UpdateFcn = @(obj,event_obj) GraphCursorCallback(obj,event_obj,sg,G,sg_assigned_ids,sg_possible_ids);

%c = uicontextmenu;
%m1 = uimenu(c,'Label','image','Callback',@image_tracklet_callback);

% create a highligh menu



% highligh first ID


% create context menu for nodes



function highlight_id(src,event,id)

    if nargin<3
        id=src;
    end
    
    if ischar(id)
        id = find(strcmp(id,G.usedIDs));
        
    end
    idstr = G.Trck.usedIDs{id};
    % remove all highlights
    highlight(h,sg,'Marker','o','EdgeColor','b','NodeColor','b','LineWidth',1,'MarkerSize',5)
    
    
    id_nodes = find(sg_possible_ids(:,id)|sg_assigned_ids(:,id));
    
    from = sg.Edges.EndNodes(:,1);
    to = sg.Edges.EndNodes(:,2);
    
    to_keep = ismember(from,sg.Nodes.Name(id_nodes)) & ismember(to,sg.Nodes.Name(id_nodes));
    
    idsg = rmedge(sg,find(~to_keep));
    
    highlight(h,idsg,'EdgeColor','r','NodeColor','r','LineWidth',2,'MarkerSize',8);
    assigned_nodes =  find(sg_assigned_ids(:,id));
    highlight(h,assigned_nodes,'NodeColor','m','MarkerSize',8);
    idsrcnodes = src_nodes(strcmp(idstr,{sg_trjs(src_nodes).autoID}));
    idsrcnodes = intersect(idsrcnodes,id_nodes);
    
    highlight(h,idsrcnodes,'NodeColor','g','MarkerSize',8);
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