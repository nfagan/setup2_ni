sd = debug_gaze_task_sync();

%%

win_rect = sd.gaze_coord_transform.calibration_rect_m1;

ni = read_ni_data( fullfile(pwd, 'ni.bin') );

m1_xy = convert_m1_gaze_position_to_pixels( ...
  sd.gaze_coord_transform, get_m1_xy_from_ni_data(ni) );
% get timestamps for every sample of NI data, expressed in terms of
% matlab's (the task's) clock.
do_extrapolate = true;
ni_mat_t = transform_ni_clock_to_matlab_clock( ...
    get_sync_channel_from_ni_data(ni) ...
  , datetime ...
  , sd.t0 ...
  , do_extrapolate ...
);
%%

sync_chan = get_sync_channel_from_ni_data( ni );
sync_pulse = get_ni_sync_pulse( sync_chan );
figure(1); clf; hold on;
plot( sync_pulse * 5 );
plot( sync_chan );

%%

FS = NIInterface.get_sample_rate();

cx = mean( win_rect([1, 3]) );
cy = mean( win_rect([2, 4]) );

figure(1); clf;
axs = plots.panels( numel(sd.task_data) );

for i = 1:numel(sd.task_data)
  fs_m1 = sd.task_data{i}.fixation;
%   slop = 5e-3;
  slop = 0;
  if fs_m1.acquired_ts
    [~, ind_entry] = min( abs((fs_m1.entered_ts(1) + slop) - ni_mat_t) );
    [~, ind_acquire] = min( abs((fs_m1.acquired_ts(1) + slop) - ni_mat_t) );
  else
    continue
  end
  
  look_back_approx_ms = 1e3 * (FS/1e3);
  look_ahead_approx_ms = 1e3 * (FS/1e3);
  
  t_series = -look_back_approx_ms:look_ahead_approx_ms;
  m1_aligned = m1_xy(ind_entry-look_back_approx_ms:ind_entry+look_ahead_approx_ms, :);
  m1_acq = m1_xy(ind_acquire, :);

  scatter( axs(i), m1_aligned(:, 1), m1_aligned(:, 2), 0.1 );
  hold( axs(i), 'on' );
  scatter( axs(i), m1_aligned(look_back_approx_ms, 1), m1_aligned(look_back_approx_ms, 2), 16 );
  scatter( axs(i), m1_acq(:, 1), m1_acq(:, 2), 16 );

  x0 = cx - sd.stimulus_size * 0.5;
  y0 = cy - sd.stimulus_size * 0.5;

  rectangle( axs(i), 'position', [x0, y0, sd.stimulus_size, sd.stimulus_size] );
end