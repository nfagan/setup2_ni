classdef TaskData < handle
  properties
    entries;
    video_interface;
    sync_interface;
    save_p;
    save_filename;
    matlab_time;
    params;
  end
  
  methods
    function obj = TaskData(...
        save_p, save_filename, video_interface, matlab_time, params)
      obj.entries = TrialRecord.empty;
      obj.save_p = save_p;
      obj.save_filename = save_filename;
      obj.video_interface = video_interface;
      obj.matlab_time = matlab_time;
      obj.params = params;
    end

    function n = num_entries(obj)
      n = numel( obj.entries );
    end
    
    function entry = push(obj)
      entry = TrialRecord();
      obj.entries(end+1) = entry;
    end

    function sd = get_saveable_data(obj)
      if ( isempty(obj.video_interface) )
        vid_data = [];
      else
        vid_data = get_saveable_data( obj.video_interface );
      end

      if ( isempty(obj.sync_interface) )
        sync_data = [];
      else
        sync_data = get_saveable_data( obj.sync_interface );
      end

      try
        [m1_calib_p, m2_calib_p] = get_latest_fv_far_plane_calibration_file_names();        
      catch err
        warning( err.message );
        m1_calib_p = '';
        m2_calib_p = '';
      end

      if ( ~isempty(m1_calib_p) )
        m1_calib = load( m1_calib_p );
      else
        m1_calib = [];
      end

      if ( ~isempty(m2_calib_p) )
        m2_calib = load( m2_calib_p );
      else
        m2_calib = [];
      end

      mt = get_saveable_data( obj.matlab_time );

      sd = struct( ...
          'trials', obj.entries ...
        , 'video_data', vid_data ...
        , 'far_plane_calibration', struct('m1', m1_calib, 'm2', m2_calib) ...
        , 'matlab_time', mt ...
        , 'params', obj.params ...
        , 'sync', sync_data ...
      );
    end
    
    function delete(obj)
      if ( ~isempty(obj.save_p) )
        saveable_data = get_saveable_data( obj );
        fname = obj.save_filename;
        save( fullfile(obj.save_p, fname), 'saveable_data' );
      end
    end
  end
end