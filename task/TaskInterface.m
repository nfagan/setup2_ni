classdef TaskInterface < handle
  properties (Constant = true)
    TASK_ABORTED_FILE_PREFIX = 'task_aborted';
  end

  properties
    t0;
    data_p = '';
    logged_video_error = false;

    windows = {};

    put_m1_gaze_in_center = false;%true;%false
    put_m2_gaze_in_center = false;

    m1_gaze_override_stack = [];
    m2_gaze_override_stack = [];

    bypass_video = false;
    bypass_ni = false;
    bypass_npxi_events = true;
    bypass_laser = true;
    bypass_reward = false;
    bypass_sync_interface = false;
    use_setup3_reward = false;

    laser_port = 'COM4';

    matlab_time;
    video_interface;
    sync_interface;
    ni_interface;
    gaze_tracker;
    setup3_reward_interface;
    npxi_events;
    laser_interface;
    task_data;
  end

  methods
    function obj = TaskInterface(t0, save_p, windows)
      obj.t0 = t0;
      obj.data_p = save_p;
      obj.windows = windows;
      obj.setup3_reward_interface = Setup3RewardInterface( ~obj.use_setup3_reward );
    end

    function tf = proceed(obj)
      % keep running while there was no error with video acquisition.
      tf = ~ParallelErrorChecker.has_error( ...
        AsyncVideoInterface.VIDEO_ERROR_FILE_PREFIX );
    end

    function push_m1_gaze_position_override(obj, m1_pos)
      obj.m1_gaze_override_stack(end+1, 1:2) = m1_pos(:)';
    end

    function pop_m1_gaze_position_override(obj)
      obj.m1_gaze_override_stack(end, :) = [];
    end

    function push_m2_gaze_position_override(obj, m2_pos)
      obj.m2_gaze_override_stack(end+1, 1:2) = m2_pos(:)';
    end

    function pop_m2_gaze_position_override(obj)
      obj.m2_gaze_override_stack(end, :) = [];
    end

    function m1_xy = get_m1_position(obj, win_m1, enable_remap,center_remap_m1)
      if ( ~isempty(obj.m1_gaze_override_stack) )
        m1_xy = obj.m1_gaze_override_stack(end, :);
        return
      end

      if ( obj.put_m1_gaze_in_center )
        m1_xy = win_m1.Center;
        if enable_remap
          m1_xy = center_remap_m1;
        end

      else
        m1_xy = get_m1( obj.gaze_tracker );
      end
    end

    function m2_xy = get_m2_position(obj, win_m2,enable_remap,center_remap_m2)
      if ( ~isempty(obj.m2_gaze_override_stack) )
        m2_xy = obj.m2_gaze_override_stack(end, :);
        return
      end
      
      if ( obj.put_m2_gaze_in_center )
        m2_xy = win_m2.Center;
        if enable_remap
          m2_xy = center_remap_m2;
        end
      else
        m2_xy = get_m2( obj.gaze_tracker );
      end
    end

    function deliver_reward(obj, chans, duration_s)
      if ( ~obj.bypass_reward )
        if ( obj.use_setup3_reward )
          trigger( obj.setup3_reward_interface, chans, duration_s );
        else
          reward_trigger( obj.ni_interface, chans, duration_s );
        end
      end
    end

    function r = elapsed_time(obj)
      r = seconds( datetime() - obj.t0 );
    end

    function set_t0(obj, t0)
      obj.t0 = t0;
      obj.matlab_time.clock_t0 = t0;
    end

    function initialize(obj)
      ParallelErrorChecker.clear_error( TaskInterface.TASK_ABORTED_FILE_PREFIX );

      obj.matlab_time = MatlabTimeSync( obj.t0 );

      % video
      %
      %
      obj.video_interface = AsyncVideoInterface( obj.bypass_video, obj.data_p );
      initialize( obj.video_interface );
      
      % ni
      %
      %
      obj.ni_interface = NIInterface( obj.bypass_ni );
      initialize( obj.ni_interface, fullfile(obj.data_p, 'ni.bin') );

      % sync interface
      %
      %
      obj.sync_interface = SyncInterface( 2, obj.bypass_sync_interface );
      initialize( obj.sync_interface );

      %
      %
      % setup3 reward interface
      initialize( obj.setup3_reward_interface );

      % gaze tracker
      %
      %
      obj.gaze_tracker = NIGazeTracker();
      set_calibration_rects( obj.gaze_tracker, obj.windows );

      % neuro pixel events
      %
      %
      obj.npxi_events = NPXIEventsInterface( obj.bypass_npxi_events );
      initialize( obj.npxi_events );

      % laser
      %
      % 
      obj.laser_interface = LaserInterface( obj.laser_port, obj.bypass_laser );
      initialize( obj.laser_interface );

      % wait for pulse train to begin.
      wait_for_sync_pulse_train_to_likely_begin( obj.ni_interface );
    end

    function update(obj)
      res = tick( obj.ni_interface );
      update( obj.gaze_tracker, res );
      update( obj.setup3_reward_interface );
      
      if ( ~obj.logged_video_error )
        % check whether an error has occurred in video acquisition
        had_err = ParallelErrorChecker.check_log_error( ...
          AsyncVideoInterface.VIDEO_ERROR_FILE_PREFIX );
        if ( had_err )
          obj.logged_video_error = true;
        end
      end
    end

    function finish(obj)
      obj.matlab_time.finish( datetime() );
    end

    function shutdown(obj)
      ParallelErrorChecker.set_error( TaskInterface.TASK_ABORTED_FILE_PREFIX, 'aborted' );

      delete( obj.ni_interface );
      delete( obj.setup3_reward_interface );
      % @NOTE: Task data should be deleted after NI shuts down, but before
      % video interface is deleted (bc the video data may be needed
      % as part of the task data shutdown procedure).
      delete( obj.task_data );
      % @NOTE: sync interface should be deleted after task data, to allow
      % its data to be saved
      delete( obj.sync_interface );
      delete( obj.video_interface );
      delete( obj.laser_interface );
      delete( obj.npxi_events );
    end

    function delete(obj)
      shutdown( obj );
    end
  end
end