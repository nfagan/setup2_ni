function sd = debug_gaze_task_sync()

win = ptb.Window( [0, 0, 1280, 1024] );
open( win );

stimulus_size = 100;

gaze_tracker = NIGazeTracker();
set_calibration_rects( gaze_tracker, {win, win} );

ni = NIInterface();
initialize( ni, fullfile(pwd, 'ni.bin') );

sync_interface = SyncInterface( 1 );
initialize( sync_interface );

task_t0 = datetime();
trigger( sync_interface, 0, task_t0, tic );

task_datas = {};
while ( ~abort_task() )
  task_data = struct();
  task_data.fixation = state_fixation();
  state_iti();
  task_datas{end+1} = task_data;
end

shutdown( ni );

sd = struct( ...
    'sync', get_saveable_data(sync_interface) ...
  , 'task_data', {task_datas} ...
  , 't0', task_t0 ...
  , 'gaze_coord_transform', gaze_tracker.gaze_coord_transform ...
  , 'stimulus_size', stimulus_size ...
);

%%

  function t = time_cb()
    t = seconds( datetime() - task_t0 );
  end

  function task_loop()
    res = tick( ni );
    update( gaze_tracker, res );
  end

  function tf = abort_task()
    tf = ptb.util.is_esc_down();
  end

  function state_iti()
    loc_t0 = tic();

    while ( ~abort_task() && toc(loc_t0) < 5 )
      task_loop();
      do_draw();
    end

    function do_draw()
      flip( win, false );
    end
  end

  function res = state_fixation()
    tracker = FixationStateTracker( time_cb() );

    while ( ~abort_task() )
      task_loop();
      do_draw();

      targ_rect = get_target_rect();
      xy = get_m1( gaze_tracker );
      update( tracker, xy(1), xy(2), time_cb(), 0.1, targ_rect );
      if ( tracker.acquired )
        break
      end
    end

    res = tracker;

    function r = get_target_rect()
      s = stimulus_size;
      cen = win.Center;
      r = [ cen(1) - s * 0.5, cen(2) - s * 0.5, cen(1) + s * 0.5, cen(2) + s * 0.5 ];
    end

    function do_draw()
      xy1 = get_m1( gaze_tracker );
      s = 20;
      r_xy = [ xy1(1) - s, xy1(2) - s, xy1(1) + s, xy1(2) + s ];

      r = get_target_rect();
      Screen( 'FillRect', win.WindowHandle, [255, 255, 255], r );
      Screen( 'FillRect', win.WindowHandle, [255, 0, 0], r_xy );
      flip( win, false );
    end
  end
end