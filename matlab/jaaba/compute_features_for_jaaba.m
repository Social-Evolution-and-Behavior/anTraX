function compute_features_for_jaaba(Trck, m)


mjdir = [Trck.trackingdir,'jaaba',filesep,Trck.expname,'_',num2str(m),filesep];
perframedir = [mjdir,'perframe',filesep];


% load trx
load([mjdir,'trx.mat'],'trx');

scale = Trck.get_param('geometry_rscale');

%%%%%%%%%%%% appearance features %%%%%%%%%%%%

% real blob area
for i=1:length(trx)
    features.antrax_blob_area{i} = scale*scale*trx(i).blobarea;
    features.antrax_dblob_area{i} = diff(features.antrax_blob_area{i})./trx(i).dt;
end
feature_units.antrax_blob_area = parseunits('mm^2');
feature_units.antrax_dblob_area = parseunits('mm^2/s');

%%%%%%%%%%%% arena features %%%%%%%%%%%%%%%%%

msk = Trck.Masks.roi(:,:,1);
sz = size(msk);
[dist_to_wall_map, closest_point_idx] = bwdist(~msk);
[x_map, y_map] = meshgrid(1:sz(2),1:sz(1));
[closest_point_y_map,  closest_point_x_map] = ind2sub(sz,closest_point_idx);
angle_to_wall_map = atan2(closest_point_y_map-y_map, closest_point_x_map-x_map);

[~,ix_max] = max(dist_to_wall_map(:));

[arena_center_y, arena_center_x] = ind2sub(sz, ix_max);

% distance/angle from wall and derivative
for i=1:length(trx)
    ix = sub2ind(sz,round(trx(i).y),round(trx(i).x));
    ok = ~isnan(ix);
    features.antrax_dist_to_wall{i} = nan(1,length(ix));
    features.antrax_angle_to_wall{i} = nan(1,length(ix));
    
    features.antrax_dist_to_wall{i}(ok) = scale*dist_to_wall_map(ix(ok));
    features.antrax_ddist_to_wall{i} = diff(features.antrax_dist_to_wall{i})./trx(i).dt;
    features.antrax_angle_to_wall{i}(ok) = trx(i).theta(ok) - angle_to_wall_map(ix(ok));
    features.antrax_dangle_to_wall{i} = diff(features.antrax_angle_to_wall{i})./trx(i).dt;
end
feature_units.antrax_dist_to_wall = parseunits('mm');
feature_units.antrax_ddist_to_wall = parseunits('mm/2');
feature_units.antrax_angle_to_wall = parseunits('rad');
feature_units.antrax_dangle_to_wall = parseunits('rad/s');

% distance/angle from center
for i=1:length(trx)
    features.antrax_dist_to_center{i} = scale * sqrt((trx(i).y - arena_center_y).^2 + (trx(i).x - arena_center_x).^2);
    features.antrax_ddist_to_center{i} = diff(features.antrax_dist_to_center{i})./trx(i).dt;
    features.antrax_angle_to_center{i} = trx(i).theta - atan2(trx(i).y - arena_center_y, trx(i).x - arena_center_x);
    features.antrax_dangle_to_center{i} = diff(features.antrax_angle_to_center{i})./trx(i).dt;
end
feature_units.antrax_dist_to_center = parseunits('mm');
feature_units.antrax_ddist_to_center = parseunits('mm/2');
feature_units.antrax_angle_to_center = parseunits('rad');
feature_units.antrax_dangle_to_center = parseunits('rad/s');


% distance/angle from open boundry

msk = Trck.Masks.open_boundry_perimeter(:,:,1);
sz = size(msk);
[dist_to_open_map, closest_point_idx] = bwdist(~msk);
[x_map, y_map] = meshgrid(1:sz(2),1:sz(1));
[closest_point_y_map,  closest_point_x_map] = ind2sub(sz,closest_point_idx);
angle_to_open_map = atan2(closest_point_y_map-y_map, closest_point_x_map-x_map);


for i=1:length(trx)
    ix = sub2ind(sz,round(trx(i).y),round(trx(i).x));
    ok = ~isnan(ix);
    features.antrax_dist_to_openwall{i} = nan(1,length(ix));
    features.antrax_angle_to_openwall{i} = nan(1,length(ix));
    
    features.antrax_dist_to_openwall{i}(ok) = scale*dist_to_open_map(ix(ok));
    features.antrax_ddist_to_openwall{i} = diff(features.antrax_dist_to_openwall{i})./trx(i).dt;
    features.antrax_angle_to_openwall{i}(ok) = trx(i).theta(ok) - angle_to_open_map(ix(ok));
    features.antrax_dangle_to_openwall{i} = diff(features.antrax_angle_to_openwall{i})./trx(i).dt;
end
feature_units.antrax_dist_to_openwall = parseunits('mm');
feature_units.antrax_ddist_to_openwall = parseunits('mm/2');
feature_units.antrax_angle_to_openwall = parseunits('rad');
feature_units.antrax_dangle_to_openwall = parseunits('rad/s');

%%%%%%%%%% social features %%%%%%%%%%%%%%%%%%%

for i=1:length(trx)
    allx(i,:) = torow(trx(i).x);
    ally(i,:) = torow(trx(i).y);
end

medx = median(allx,1,'omitnan');
medy = median(allx,1,'omitnan');

% distance/angle to median

for i=1:length(trx)
    features.antrax_dist_to_median{i} = scale * sqrt((trx(i).y - medy).^2 + (trx(i).x - medx).^2);
    features.antrax_ddist_to_median{i} = diff(features.antrax_dist_to_median{i})./trx(i).dt;
    features.antrax_angle_to_median{i} = trx(i).theta - atan2(trx(i).y - medy, trx(i).x - medx);
    features.antrax_dangle_to_median{i} = diff(features.antrax_angle_to_median{i})./trx(i).dt;
end

feature_units.antrax_dist_to_median = parseunits('mm');
feature_units.antrax_ddist_to_median = parseunits('mm/2');
feature_units.antrax_angle_to_median = parseunits('rad');
feature_units.antrax_dangle_to_median = parseunits('rad/s');

% number of ants in blob
for i=1:length(trx)
   
    d = scale*sqrt((allx - trx(i).x).^2 + (ally - trx(i).y).^2);
    features.antrax_nants_in_blob{i} = sum(d<0.001,2);
    features.antrax_frac_in_blob{i} = mean(d<0.001,2);
end

feature_units.antrax_nants_in_blob = parseunits('unit');
feature_units.antrax_frac_in_blob = parseunits('unit');


%%%%%%%%%% trajectory features %%%%%%%%%%%%%%%

% curvature


%%%%%%%%%%% save %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

names = fieldnames(features);

for i=1:length(names)
   
    name = names{i};
    data = features.(name);
    units = feature_units.(name);
    
    save([perframedir,name,'.mat'],'data','units');
    
end





end