function decorate_graph(app, id)


if ischar(id)
    id = find(strcmp(id,app.G.usedIDs));
end


idstr = app.G.Trck.usedIDs{id};
            
            
% all including noant
highlight(app.GraphPlot,app.sg,'Marker','o','EdgeColor',[0.9,0.9,0.9],'NodeColor',[0.9,0.9,0.9],'LineWidth',2,'MarkerSize',2)

% now without noant
highlight(app.GraphPlot,app.sg_ant_subgraph,'Marker','s','EdgeColor',[0.7,0.7,0.7],'NodeColor',[0.7,0.7,0.7],'LineWidth',1,'MarkerSize',4)

% now single ant nodes
highlight(app.GraphPlot,app.sg_single_nodes,'Marker','o','EdgeColor',[0.7,0.7,0.7],'NodeColor',[0.7,0.7,0.7],'LineWidth',1,'MarkerSize',4)

% now src nodes
highlight(app.GraphPlot,app.sg_src_nodes,'Marker','o','EdgeColor',[0.3,0.3,0.3],'NodeColor',[0.3,0.3,0.3],'LineWidth',1,'MarkerSize',4)



id_nodes = find(app.sg_possible_ids(:,id)|app.sg_assigned_ids(:,id));

from = app.sg.Edges.EndNodes(:,1);
to = app.sg.Edges.EndNodes(:,2);

to_keep = ismember(from,app.sg.Nodes.Name(id_nodes)) & ismember(to,app.sg.Nodes.Name(id_nodes));

idsg = rmedge(app.sg,find(~to_keep));

cm=colormap('lines');
cm=cm(1:7,:);

highlight(app.GraphPlot,idsg,'EdgeColor',cm(1,:),'NodeColor',cm(2,:),'LineWidth',3,'MarkerSize',6);
assigned_nodes =  find(app.sg_assigned_ids(:,id));

highlight(app.GraphPlot,assigned_nodes,'NodeColor',cm(1,:),'MarkerSize',6);

idsrcnodes = app.sg_src_nodes(strcmp(idstr,{app.sg_trjs(app.sg_src_nodes).autoID}));
idsrcnodes = intersect(idsrcnodes,id_nodes);

highlight(app.GraphPlot,idsrcnodes,'NodeColor',cm(5,:),'MarkerSize',8);