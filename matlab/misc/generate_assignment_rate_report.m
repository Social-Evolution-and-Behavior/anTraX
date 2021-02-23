function generate_assignment_rate_report(Trck, XY)

T = parse_time_config(Trck,'command','remove');

if Trck.get_param('geometry_multi_colony')
    for i=1:Trck.Ncolonies
        c = Trck.colony_labels{i};
        Tc = T(strcmp(T.colony,c) |  strcmp(T.colony,'all'),:);
        Tc.colony = []; 
        for j=1:Trck.NIDs
            id = Trck.usedIDs{j};
            Tid = Tc(strcmp(Tc.id,id) |  strcmp(Tc.id,'all'),:);
            ndeadframes = count_frames(Tid);
            nassignedframes = sum(~isnan(XY.(c).(id)(:,1)));
            ntotframes = size(XY.(c).(id),1);
            a(i,j) = nassignedframes/(ntotframes - ndeadframes);
        end
    end
else
    for j=1:Trck.NIDs
        id = Trck.usedIDs{j};
        Tid = T(strcmp(T.id,id) |  strcmp(T.id,'all'),:);
        ndeadframes = count_frames(Tid);
        nassignedframes = sum(~isnan(XY.(id)(:,1)));
        ntotframes = size(XY.(id),1);
        a(j) = nassignedframes/(ntotframes - ndeadframes);
    end
end


total_assigment_rate = mean(a(:));


function len = count_frames(T)

    T.len = T.to - T.from + 1;
    len = sum(T.len);
    


