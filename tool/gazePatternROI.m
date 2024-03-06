%% 
% addpath( genpath('C:/Users/qigua/github/setup2_ni') );
FS = NIInterface.get_sample_rate();

%%
% data_dir = '/Volumes/external3/data/changlab/guangyao-gaze-following/raw/19-Feb-2024 15_13_15';
data_dir = 'D:\tempData\data\06-Mar-2024 12_03_36'
data_dir = 'D:\tempData\data\06-Mar-2024 12_32_50';
data_dir = 'D:\tempData\data\06-Mar-2024 12_54_25';
td = load( fullfile(data_dir, 'task_data.mat') );
ni = read_ni_data( fullfile(data_dir, 'ni.bin') );

if ( 1 )
  vr1 = VideoReader( fullfile(data_dir, 'video_1.mp4') );
  vr2 = VideoReader( fullfile(data_dir, 'video_2.mp4') );
end

%%
% time0 for matlab's (i.e., the task) clock
matlab_t0 = get_matlab_t0_from_saveable_data( td.saveable_data );

% get m1's gaze position in pixels
m1_xy = convert_m1_gaze_position_to_pixels( ...
  td.saveable_data.params.gaze_coord_transform, get_m1_xy_from_ni_data(ni) );
% get m2's gaze position in pixels
m2_xy = convert_m2_gaze_position_to_pixels( ...
  td.saveable_data.params.gaze_coord_transform, get_m2_xy_from_ni_data(ni) );
% get timestamps for every sample of NI data, expressed in terms of
% matlab's (the task's) clock.
do_extrapolate = true;
ni_mat_t = transform_ni_clock_to_matlab_clock( ...
    get_sync_channel_from_ni_data(ni) ...
  , datetime ...
  , matlab_t0 ...
  , do_extrapolate ...
);
%%

sync_chan = get_sync_channel_from_ni_data( ni );
sync_pulse = get_ni_sync_pulse( sync_chan );
figure(1); clf; hold on;
plot( sync_pulse * 5 );
plot( sync_chan );
%% ROI 
highlight_m1 = false;
if ( highlight_m1 )
  % xy_subset = [m1_px(:), m1_py(:)];
  calib_field = 'm1';
else
  % xy_subset = [m2_px(:), m2_py(:)];
  calib_field = 'm2';
end
face_roi = [ 0, 0, 5, 5 ];
eye_roi = [ 0, 0, 5, 5 ];
% face_roi = get_face_roi_from_calibration_file( td.saveable_data.far_plane_calibration.(calib_field), 0, 0 );
% eye_roi = get_eye_roi_from_calibration_file( td.saveable_data.far_plane_calibration.(calib_field), 100, 100 );
screen_height = td.saveable_data.params.screen_height;
monitor_height = td.saveable_data.params.monitor_height;
enable_remap = td.saveable_data.params.enable_remap;
m1_Width = td.saveable_data.params.gaze_coord_transform.calibration_rect_m1(3);
m1_Height = td.saveable_data.params.gaze_coord_transform.calibration_rect_m1(4);
m2_Width = td.saveable_data.params.gaze_coord_transform.calibration_rect_m2(3);
m2_Height = td.saveable_data.params.gaze_coord_transform.calibration_rect_m2(4);
moitor_screen_edge_to_table = 2.2;% cm
if enable_remap
  y_axis_screen = screen_height/(2*monitor_height);%0.25;%
  y_axis_remap = (monitor_height-(screen_height/2-moitor_screen_edge_to_table))/monitor_height;%x/(2*27.3);%0.25;%
  
  if screen_height == 0
    y_axis_screen = 0.75;
    y_axis_remap = 0.75;
  end
    
  center_screen_m1 = [0.5*m1_Width,y_axis_screen*m1_Height];
  center_screen_m2 = [0.5*m2_Width,y_axis_screen*m2_Height];
  center_remap_m1 = [0.5*m1_Width,y_axis_remap*m1_Height];
  center_remap_m2 = [0.5*m2_Width,y_axis_remap*m2_Height];
else

  center_screen_m1 = [0.5*m1_Width,0.5*m1_Height];
  center_screen_m2 = [0.5*m2_Width,0.5*m2_Height];
  center_remap_m1 = center_screen_m1;
  center_remap_m2 = center_screen_m2;

end
fix_cross_size = td.saveable_data.params.fix_cross_size_m1;
cross_padding = td.saveable_data.params.cross_padding_m1;
cross_roi = [center_remap_m1-fix_cross_size/2,center_remap_m1+fix_cross_size/2];
reward_roi = [center_remap_m1-fix_cross_size/2-cross_padding/2,center_remap_m1+fix_cross_size/2+cross_padding/2];
%% 
figure(2);clf; %ax = gca; hold( ax, 'on' );
kk = 1;
for i = 1:length(td.saveable_data.trials)
% for i = [27, 34]
  subplot(7,8, i ...
    );
  title(['trial ',num2str(i)])
  % title('trial',i)
  desired_trial = td.saveable_data.trials(i);
  if ( highlight_m1 )
    fs_m1 = desired_trial.fixation_with_block_rule.fixation_state_m1;
    monk_pos = m1_xy;
  else
    fs_m1 = desired_trial.fixation_with_block_rule.fixation_state_m2;
    monk_pos = m2_xy;
  end
  % 
  % if ( isempty(desired_trial.actor_response) ), continue; end
  % fs_m1 = desired_trial.actor_response.actor_choice.StateTrackers{1};

%   slop = 0.005;
  slop = td.saveable_data.sync(1).sync_times(1).parent_time_to_post_trigger_duration;
%   slop = 5e-3;
%   slop = 0;
  if fs_m1.acquired_ts
    [~, ind_acq] = min( abs((fs_m1.acquired_ts(end) + slop) - ni_mat_t) );
    [~, ind_entry] = min( abs((fs_m1.entered_ts(end) + slop) - ni_mat_t) );
  else
    continue
  end
  
  look_back_approx_ms = 1e3 * (FS/1e3);
  look_ahead_approx_ms = 1e3 * (FS/1e3);
  
  t_series = -look_back_approx_ms:look_ahead_approx_ms;
  m1_aligned = monk_pos(ind_acq-look_back_approx_ms:ind_acq+look_ahead_approx_ms, :);
  
  % figure(1); clf; ax = gca; hold( ax, 'on' );
  % plot( ax, t_series, m1_aligned(:, 1), 'r', 'DisplayName', 'x' );
  % plot( ax, t_series, m1_aligned(:, 2), 'b', 'DisplayName', 'y' );
 
  % figure(2);clf; ax = gca; hold( ax, 'on' );
  % f_tot = rand(50,9);
  sz = 5;
  c = linspace(1,10,length(m1_aligned)); % blue to yellow
  % scatter(x,y,sz,c,'filled')
  
  scatter(m1_aligned(:, 1),m1_aligned(:, 2),sz,c,'filled')
  hold on;
  plot(m1_aligned(1,1),m1_aligned(1, 2),Marker="o",Color='k')
  plot(m1_aligned(end,1),m1_aligned(end, 2),Marker="x",Color='k')

  if ( 1 )
    plot(monk_pos(ind_entry, 1), monk_pos(ind_entry, 2) ...
      , Marker="diamond", Color='r' );
    plot(monk_pos(ind_acq, 1), monk_pos(ind_acq, 2),Marker="diamond",Color='k')
  else
    plot(m1_aligned(find(t_series==-round((td.saveable_data.params.timing.initial_fixation_duration_m1)*FS)),1), ...
      m1_aligned(find(t_series==-round((td.saveable_data.params.timing.initial_fixation_duration_m1)*FS)), 2),Marker="diamond",Color='r')
    plot(m1_aligned(find(t_series==0),1),m1_aligned(find(t_series==0), 2),Marker="diamond",Color='k')
  end

  plot(m1_aligned(find(t_series==0),1),m1_aligned(find(t_series==0), 2),Marker="diamond",Color='k')
  
  if kk ==1
    kk = kk+1;
%     legend('gaze trajectory','start','end','entered','acquired')
  end

  plt_roi = @(roi,ec) ...
    rectangle( gca ...
    , 'position', [roi(1), roi(2), diff(roi([1, 3])), diff(roi([2, 4]))]...
    ,'EdgeColor',ec);
  
  plt_roi( face_roi,'red' );
  plt_roi( eye_roi,'red' );
  plt_roi( cross_roi,'black' );
  plt_roi( reward_roi,'black');
  xlim([0,m1_Width])
  ylim([0,m1_Height+200])
  title(['trial ',num2str(i)])
end

%%  video data

figure(3);clf; %ax = gca; hold( ax, 'on' );
for i = 1:length(td.saveable_data.trials)
  subplot(7,8, i ...
    );
  title(['trial ',num2str(i)])
  % title('trial',i)
  desired_trial = td.saveable_data.trials(i);
  if ( highlight_m1 )
    fs_m1 = desired_trial.fixation_with_block_rule.fixation_state_m1;
    monk_pos = m1_xy;
    vr = vr1;
    vid_ts = datetime( td.saveable_data.video_data.vs1.Value.vid_time );
  else
    fs_m1 = desired_trial.fixation_with_block_rule.fixation_state_m2;
    monk_pos = m2_xy;
    vr = vr2;
    vid_ts = datetime( td.saveable_data.video_data.vs2.Value.vid_time );
  end

  if fs_m1.acquired_ts
    targ_t = fs_m1.acquired_ts(end);
  else
    continue
  end

  sec_vid_ts = seconds( vid_ts - matlab_t0 );
  [~, ind] = min( abs(targ_t - sec_vid_ts) );
  frame = read( vr, ind );
  imshow( frame, 'Parent', gca );  
  title(['trial ',num2str(i)])
end

%%  remake videos in "real time" by resampling to a higher sampling rate, respecting the actual frame timestamps

remake_vid_ts1 = datetime( td.saveable_data.video_data.vs1.Value.vid_time );
frame_intervals = round( diff(seconds(remake_vid_ts1 - matlab_t0)) * 1e3 );

vw = VideoWriter( fullfile(data_dir, 'video_1_resampled.mp4') );
vw.FrameRate = 1e3;
open( vw );

for i = 1:numel(frame_intervals)
  fprintf( '\n %d of %d', i, numel(frame_intervals) );
  frame = read( vr1, i );
  for j = 1:frame_intervals(i)
    writeVideo( vw, frame );
  end
end

close( vw );

%%

data_dir = 'D:/Dropbox (ChangLab)/setup2_2023_2024/behavior/pairwise_training/m1_lynch_m2_ephron/22-Feb-2024 14_33_42';
td = load( fullfile(data_dir, 'task_data.mat') );
ni = read_ni_data( fullfile(data_dir, 'ni.bin') );
%%

sync_chan = ni(:, end);
is_pos = sync_chan > 0.99;
[npxi_isles, npxi_durs] = shared_utils.logical.find_islands( is_pos );

%%

vid_ts = datetime( td.saveable_data.video_data.vs1.Value.vid_time );
sync_ts = npxi_isles(1:2:end);
sync_ts = sync_ts(1:size(vid_ts, 1));

% clock_t0 is the canonical t0 for task events
vid_t_offset = vid_ts - td.saveable_data.matlab_time.clock_t0;
sec_offset = seconds( vid_t_offset );

% choose the desired alignment time (in this case, the start of the fixation
% with block rule state)
gaze_chunk_begin = ...
  td.saveable_data.trials(27).fixation_with_block_rule.fixation_state_m1.entered_ts(end);
chunk_dur = 5;
ni_fs = 1e3;

% find the nearest synchronization timepoint to the desired alignment event
% (in this case, the start of the fixation with block rule state)
off = gaze_chunk_begin - sec_offset;
[~, nearest_beg] = min( abs(off) );
err = off(nearest_beg) * ni_fs;
% index into the array of ni samples using the synchronization pulse onset
% corresponding to the closest synchronization time point to the desired
% alignment event -- add the error between these

look_back = -1e3;
look_ahead = 0;

look_back = 500;
look_ahead = 0;

abs_beg = floor( sync_ts(nearest_beg) + err ) + look_back;
abs_end = abs_beg + chunk_dur * ni_fs + look_ahead;

t = look_back:chunk_dur*ni_fs+look_ahead;

xy = ni(abs_beg+look_back:abs_end+look_ahead, 1:2);
xy = convert_m1_gaze_position_to_pixels( td.saveable_data.params.gaze_coord_transform, xy );

tf = shared_utils.rect.inside( reward_roi, xy(1, 1), xy(1, 2) )

figure(8); clf;
plot( t, xy(:, 1), 'DisplayName', 'x' ); hold on;
plot( t, xy(:, 2), 'DisplayName', 'y' ); legend;
title( 'Gaze data' );

%%

n_sync_samples = 200;
figure(2); clf;
% subplot( 1, 2, 1 );
plot( is_pos(npxi_isles(1):npxi_isles(1)+n_sync_samples) ); hold on;
title( 'NI sync points' );

first_sync = 8e3;
sync_ib = (first_sync - 1) + find( sync_ts - sync_ts(1) < n_sync_samples );

for i = 1:numel(sync_ib)
  vid_t = vid_ts(sync_ib(i), :);
  text( gca, sync_ts(sync_ib(i)) - sync_ts(first_sync), 1 - i * 0.3, string(vid_t) );
end

% subplot( 1, 2, 2 );
plot( ni(npxi_isles(first_sync):npxi_isles(first_sync)+n_sync_samples, 1:2) );
