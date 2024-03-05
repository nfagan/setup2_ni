%   NIInterface
%   
%     This class presents a friendlier interface to the mex function
%     `ni_mex`, responsible for interfacing with the NI DAQ card for
%     recording gaze data, synchronizing with other hardware (e.g.
%     cameras, neural signals), and generating TTL pulses.
% 
%     see also NIInterface/initialize, NIInterface/shutdown, ni_mex.cpp

classdef NIInterface < handle
  properties (SetAccess = private, GetAccess = public)
    dummy = false;
    initialized = false;
    verbose = true;
  end

  methods
    function obj = NIInterface(dummy)
      
      %   NIINTERFACE -- Interface constructor.
      %
      %     ni = NIInterface( is_dummy ); constructs the interface object
      %     `ni`. Optionally specify `is_dummy`, a logical scalar, to
      %     indicate whether to simulate the interface.
      %
      %     See also NIInterface/initialize
      
      if ( nargin == 0 )
        dummy = false;
      end
      
      validateattributes( dummy, {'logical'}, {'scalar'}, mfilename, 'dummy' );
      obj.dummy = dummy;
    end

    function info = get_meta_info(obj)

      %   GET_META_INFO -- Get information about build configuration.
      %
      %     info = get_meta_info( obj ); return static (i.e, compile-time)
      %     meta-data about the ni interface / mex file. For example,
      %     `info` specifies the initial timeout before the synchronization
      %     pulse train is begun.
      %
      %     See also NIInterface

      info = NIInterface.get_meta_info_impl();
    end

    function initialize(obj, dst_file_p)
      
      %   INITIALIZE -- Initialize interface.
      %
      %     initialize( obj, dst_file_p ); initializes the underlying 
      %     NI interface and begins recording data to `dst_file_p`,
      %     a char vector.
      %
      %     See also NIInterface, NIInterface/shutdown, NIInterface/tick
      
      validateattributes( ...
        dst_file_p, {'char'}, {'scalartext'}, mfilename, 'dst_file_p' );

      shutdown( obj );

      if ( obj.dummy )
        return
      end

      NIInterface.start( dst_file_p );
      obj.initialized = true;
    end

    function wait_for_sync_pulse_train_to_likely_begin(obj)

      %   WAIT_FOR_SYNC_PULSE_TRAIN_TO_LIKELY_BEGIN
      %
      %     Pause for a number of seconds such that, with high probability,
      %     the sync pulse train will have begun by the time this function
      %     returns.
      %
      %     This is an approximate timeout; you may with to add padding
      %     to the timeout for a "more robust" solution.
      %
      %     See also NIInterface

      if ( ~obj.dummy )
        ni_meta_info = get_meta_info( obj );
        WaitSecs( ni_meta_info.sync_pulse_init_timeout );
      end
    end

    function shutdown(obj)
      
      %   SHUTDOWN -- Deinitialize interface.
      %
      %     See also NIInterface/initialize
      
      if ( obj.initialized )
        res = NIInterface.stop();
        if ( res.any_dropped_sample_buffers )
          fprintf( ['\n\n\n\n This session of NI-daq data is incomplete!' ...
            , ' Some sample buffers were discarded \n\n\n'] );
        elseif ( obj.verbose )
          fprintf( '\n[NI-INFO]: OK: NI reports no samples were lost / discarded.' );
        end
        if ( obj.verbose )
          fprintf( '\n[NI-INFO]: %d NI-daq sample buffers were free, at minimum' ...
            , res.min_num_sample_buffers );
          fprintf( '\n[NI-INFO]: %d NI-daq samples acquired' ...
            , res.num_input_samples_acquired );
        end
      end

      obj.initialized = false;
    end

    function res = tick(obj)
      
      %   TICK -- Update interface.
      %
      %     res = tick( ni ); updates the underlying NI interface and
      %     returns the latest available sample of gaze data in `res`. If 
      %     the interface is in simulation mode (i.e., dummy is true), or
      %     if uninitialized, then all fields of `res` are 0.
      %
      %     See also NIInterface/initialize
      
      if ( ~obj.initialized )
        if ( ~obj.dummy )
          warning( ['Attempting to update, but interface is not yet initialized;' ...
            , ' call initialize() first, or specify dummy = true to enable' ...
            , ' simulation mode.'] );
        end
        res = empty_update_result();
      else
        res = NIInterface.update();
      end
    end
    
    function pulse_trigger(obj, chans, v, dur_s)
      
      %   PULSE_TRIGGER -- Trigger pulse with custom voltage.
      %
      %     pulse_trigger( ni, chan, v, dur_s ); writes an analog pulse 
      %     with voltage `v` of `dur_s` (a double scalar) duration to 
      %     channel `chan` (a double scalar). Channel indices are 0-based!
      %
      %     pulse_trigger( ni, chans, v, dur_s ); triggers pulses of `v`
      %     voltage and `dur_s` duration on `chans` channels.
      %
      %     See also NIInterface/tick, NIInterface/initialize,
      %       NIInterface/reward_trigger
      
      if ( ~obj.initialized )
        return
      end

      for i = 1:numel(chans)
        NIInterface.trigger_custom_pulse( chans(i), v, dur_s );
      end
    end

    function reward_trigger(obj, chans, dur_s)
      
      %   REWARD_TRIGGER -- Trigger reward.
      %
      %     reward_trigger( ni, chan, dur_s ); writes an analog TTL pulse 
      %     of `dur_s` (a double scalar) duration to channel `chan` (a
      %     double scalar). Channel indices are 0-based!
      %
      %     reward_trigger( ni, chans, dur_s ); triggers pulses of `dur_s`
      %     duration on `chans` channels.
      %
      %     reward_trigger( ni, chans, durs ); where `durs` is an array the
      %     same size as `chans` triggers pulses of respective durations to
      %     each channel.
      %
      %     EX //
      %     reward_trigger( ni, 0, 50e-3 ); writes a 50ms pulse to channel
      %     0 (the first channel).
      %
      %     See also NIInterface/tick, NIInterface/initialize,
      %       NIInterface/pulse_trigger

      if ( numel(dur_s) ~= 1 )
        assert( numel(dur_s) == numel(chans) ...
          , 'Expected either a scalar duration or one duration per channel.' );
      end
      
      if ( ~obj.initialized )
        return
      end

      for i = 1:numel(chans)
        if ( numel(dur_s) == 1 )
          NIInterface.trigger_reward( chans(i), dur_s );
        else
          NIInterface.trigger_reward( chans(i), dur_s(i) );
        end
      end
    end

    function delete(obj)
      shutdown( obj );
    end
  end

  methods (Static = true)
    function r = get_empty_update_result()
      r = empty_update_result();
    end

    function r = get_sample_rate()

      %   GET_SAMPLE_RATE -- Get sample rate of DAQ
      %
      %     See also NIInterface

      res = NIInterface.get_meta_info_impl();
      r = res.sample_rate;
    end

    function r = get_sync_pulse_hz()

      %   GET_SYNC_PULSE_HZ -- Get counter output synchronization pulse
      %     frequency.
      %
      %     See also NIInterface

      res = NIInterface.get_meta_info_impl();
      r = res.sync_pulse_hz;
    end
  end

  methods (Static = true, Access = private)
    function start(dst_p)
      ni_mex( uint32(0), dst_p );
    end

    function trigger_reward(channel, dur_s)
      ni_mex( uint32(2), channel, dur_s );
    end
    
    function trigger_custom_pulse(channel, v, dur_s)
      ni_mex( uint32(3), channel, v, dur_s );
    end

    function res = update()
      res = ni_mex( uint32(1) );
    end

    function res = stop()
      res = ni_mex( uint32(4) );
    end

    function mi = get_meta_info_impl()
      mi = ni_mex( uint32(5) );
    end
  end
end

function res = empty_update_result()

res = struct();
res.pupil1 = 0;
res.x1 = 0;
res.y1 = 0;
res.pupil2 = 0;
res.x2 = 0;
res.y2 = 0;

end