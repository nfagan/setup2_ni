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

    function shutdown(obj)
      
      %   SHUTDOWN -- Deinitialize interface.
      %
      %     See also NIInterface/initialize
      
      if ( obj.initialized )
        NIInterface.stop();
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

    function reward_trigger(obj, chan, dur_s)
      
      %   REWARD_TRIGGER -- Trigger reward.
      %
      %     reward_trigger( ni, chan, dur_s ); writes an analog TTL pulse 
      %     of `dur_s` (a double scalar) duration to channel `chan` (a
      %     double scalar). Channel indices are 0-based!
      %
      %     EX //
      %     reward_trigger( ni, 0, 50e-3 ); writes a 50ms pulse to channel
      %     0 (the first channel).
      %
      %     See also NIInterface/tick, NIInterface/initialize
      
      if ( ~obj.initialized )
        return
      end

      NIInterface.trigger_reward( chan, dur_s );
    end

    function delete(obj)
      shutdown( obj );
    end
  end

  methods (Static = true)
    function start(dst_p)
      ni_mex( uint32(0), dst_p );
    end

    function trigger_reward(channel, dur_s)
      ni_mex( uint32(2), channel, dur_s );
    end

    function res = update()
      res = ni_mex( uint32(1) );
    end

    function stop()
      ni_mex( uint32(3) );
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