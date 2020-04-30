function prmtrs = default_params(Trck, name) %#ok<*INUSD>


prmtrs = struct('null',[]);


prmtrs.tagged = false;
prmtrs.tagging_type = 'individually-tagged';
prmtrs.symmetric_tags = false;

%% tracking run options

prmtrs.tracking_batch = false;
prmtrs.tracking_max_tracklet_length = 600;
prmtrs.tracking_saveimages = true;
prmtrs.tracking_saveavi = false;
prmtrs.tracking_post_commands = {};
prmtrs.single_video_post_commands = {};
prmtrs.tracking_classifyaftertracking = false;

%% Video

prmtrs.videos_reader = 'ffreader';
prmtrs.videos_first_frame_to_track = 1;
prmtrs.videos_track_on_interrupt = false;
prmtrs.videos_downsample = false;
prmtrs.videos_downsample_factor = 1;

%% Geometry

prmtrs.geometry_scale0 = 9.3611e-05;
prmtrs.geometry_rscale = prmtrs.geometry_scale0;
prmtrs.geometry_scale_tool_meas = 1;
prmtrs.geometry_scale_tool = 'Line';
prmtrs.geometry_scale_tool_params = struct('type','');
prmtrs.geometry_arenacenter = [1,1];
prmtrs.geometry_Ncolonies = 1;
prmtrs.geometry_colony_labels = {''};
prmtrs.geometry_multi_colony = false;
prmtrs.geometry_multi_colony_numbering = 'Vertical';
prmtrs.geometry_multi_colony_circ_shift = 0;

prmtrs.geometry_open_boundry = false;


%% Segmentation 

prmtrs.segmentation_use_max_rgb = false;
prmtrs.segmentation_local_z_scaling = false;

prmtrs.segmentation_illum_correct = false;
prmtrs.segmentation_illum_correct_level = 0.9;

prmtrs.segmentation_threshold = 0.14;

prmtrs.segmentation_IntensityFilter = false;
prmtrs.segmentation_MaxIntensityThreshold = 0;
prmtrs.segmentation_SplitDoubleAntBlobs = true;
prmtrs.segmentation_fillHoles = true;
prmtrs.segmentation_useConvexHull = false;
prmtrs.segmentation_ImClosing = true;
prmtrs.segmentation_ImClosingSize = 2;

prmtrs.segmentation_ImClosingStrel = strel('disk',prmtrs.segmentation_ImClosingSize);

	
prmtrs.segmentation_ImOpenning = false;
prmtrs.segmentation_ImOpenningSize = 1;
prmtrs.segmentation_ImOpenningStrel = strel('disk',prmtrs.segmentation_ImOpenningSize);
prmtrs.segmentation_MinimumBlobArea = 21;

prmtrs.segmentation_ColorContrastAdjust = false;
prmtrs.segmentation_ColorContrast = [1,1,1];
prmtrs.segmentation_color_correction_for_classification = true;

prmtrs.segmentation_blob_mask_dilate = false;
prmtrs.segmentation_blob_mask_dilate_radius = 2;

% structuring element used by 'applyMasktoIm' in SegmentIm
% prmtrs.se_graymask = strel('disk',round(10*(prmtrs.geometry_scale0/prmtrs.geometry_rscale)));

prmtrs.thrsh_meanareamax = 3.5e-6;
prmtrs.thrsh_meanareamin = 1e-6;

prmtrs.thrsh_meanareamax_0 = 3.5e-6;
prmtrs.thrsh_meanareamin_0 = 1e-6;

prmtrs.thrsh_meanarea_0 = 2.25e-6;

%% Linking 

prmtrs.linking_method = @link_blobs;

prmtrs.linking_maxspeed = 3.5e-3;
prmtrs.linking_cluster_radius_coeff = 2;
prmtrs.linking_flow_cutoff_coeff = 0.35;

prmtrs.linking_of_maxiter = 20;
prmtrs.linking_of_smoothness = 0.002;

prmtrs.linking_low_fps_hack = false;

%%%%%% OBS %%%%%%%%
%prmtrs.linking_ofconnectmin_0 = 40;
%prmtrs.linking_scale_factor = 1;
%prmtrs.linking_dilatespeed = 7e-3;   


%% Classification

prmtrs.classdir = '';

prmtrs.classification_tagColorProbThresh = 0.3;
prmtrs.classification_antColorProbThresh = 0.6;

prmtrs.classification_minAREA = 1*prmtrs.thrsh_meanareamin;
prmtrs.classification_maxAREA = 1*prmtrs.thrsh_meanareamax;
prmtrs.classification_minECCENT = 0.85;
prmtrs.classification_maxECCENT = 0.99;
prmtrs.classification_minFlipConf = 0.1;
prmtrs.classification_maxECCENT = 0.99;

%% Background

prmtrs.background_kind = 'experiment';
prmtrs.background_method = 'median';
prmtrs.background_nframes = 12;

prmtrs.background_per_subdir = false;
prmtrs.background_frame_range = [1,inf];
prmtrs.background_frame_list = [];
prmtrs.background_subdir_frame_lists = {};

prmtrs.background_to_frame = inf;
prmtrs.background_framelist = [];


%% Masks


%% Graph solving

prmtrs.graph_groupby = 'subdirs';
prmtrs.graph_groupby_every = 12;

prmtrs.graph_apply_temporal_window = true;
prmtrs.graph_apply_manual_cfg = true;
prmtrs.graph_min_cc_size = 1;
prmtrs.graph_dmin = 0.01;
prmtrs.graph_pairs_maxdepth = 10;
prmtrs.graph_max_iterations = 10;

prmtrs.graph_impossible_speed = 0.15;

prmtrs.export_use_soft = true;
prmtrs.export_too_long_to_be_wrong = 2000;



end




