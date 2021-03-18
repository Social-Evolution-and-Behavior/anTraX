function total_assigment_rate = generate_assignment_rate_report(Trck, XY)

T = parse_time_config(Trck,'command','remove');


total_frames_to_assign = 0;
total_frames_assigned = 0;

if Trck.get_param('geometry_multi_colony')
    for i=1:Trck.Ncolonies
        c = Trck.colony_labels{i};
        Tc = T(strcmp(T.colony,c) |  strcmp(T.colony,'all'),:);
        for j=1:Trck.NIDs
            id = Trck.usedIDs{j};
            Tid = Tc(strcmp(Tc.id,id) |  strcmp(Tc.id,'all'),:);
            ndeadframes = sum(Tid.to - Tid.from + 1);
            nassignedframes = sum(~isnan(XY.(c).(id)(:,1)));
            ntotframes = size(XY.(c).(id),1);
            a(i,j) = nassignedframes/(ntotframes - ndeadframes);
            total_frames_to_assign = total_frames_to_assign + ntotframes - ndeadframes;
            total_frames_assigned = total_frames_assigned + nassignedframes;
        end
    end
else
    for j=1:Trck.NIDs
        id = Trck.usedIDs{j};
        Tid = T(strcmp(T.id,id) |  strcmp(T.id,'all'),:);
        ndeadframes = sum(T.to - T.from + 1);
        nassignedframes = sum(~isnan(XY.(id)(:,1)));
        ntotframes = size(XY.(id),1);
        a(j) = nassignedframes/(ntotframes - ndeadframes);
        total_frames_to_assign = total_frames_to_assign + ntotframes - ndeadframes;
        total_frames_assigned = total_frames_assigned + nassignedframes;
    end
end

%a(isnan(a))=0;
%total_assigment_rate = mean(a(:));

total_assigment_rate = total_frames_assigned/total_frames_to_assign;


