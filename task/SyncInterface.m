classdef SyncInterface < handle
  properties (Constant)
    PORT = 'COM6';
  end

  properties
    interface;
    is_on;
    sync_times;
  end

  methods
    function obj = SyncInterface(num_sync_ts, dummy)
      if ( nargin < 2 )
        dummy = false;
      end

      validateattributes( ...
        num_sync_ts, {'double'}, {'integer'}, mfilename, 'num_sync_ts' );

      obj.interface = LaserInterface( SyncInterface.PORT, dummy );
      obj.sync_times = cell( 1, num_sync_ts );
      obj.is_on = false( 1, num_sync_ts );

      for i = 1:num_sync_ts
        obj.sync_times{i} = sync_struct( {}, {}, {} );
      end
    end

    function sd = get_saveable_data(obj)
      sd = struct( 'sync_times', obj.sync_times );
    end

    function default_trigger(obj, index, varargin)
      trigger( obj, index, datetime(), tic );
    end

    function default_trigger_async(obj, index)
      trigger( obj, index, datetime(), tic, [] );
    end

    function trigger(obj, index, parent_clock_time, parent_timer_id, for_t)
      if ( nargin < 5 )
        for_t = 0.1;
      end

      ind = index + 1;

      if ( ~obj.is_on(ind) )
        t = datetime();
        trigger( obj.interface, index );
        % amount of time between registering an event in a parent scope and 
        % executing the trigger.
        err = toc( parent_timer_id );

        obj.sync_times{ind}(end+1, 1) = sync_struct( parent_clock_time, t, err );
        obj.is_on(ind) = true;

        if ( ~isempty(for_t) )
          WaitSecs( for_t );
          trigger_off( obj, index );
        end
      else
        trigger_off( obj, index );
      end
    end

    function initialize(obj)
      initialize( obj.interface );
    end

    function shutdown(obj)
      delete( obj.interface );
    end

    function delete(obj)
      shutdown( obj );
    end
  end

  methods (Access = private)
    function trigger_off(obj, index)
      trigger( obj.interface, index );
      obj.is_on(index+1) = false;
    end
  end
end

function s = sync_struct(parent_clock_t, t, timer_err)
s = struct( 'parent_time', parent_clock_t, 'before_trigger_time', t ...
  , 'parent_time_to_post_trigger_duration', timer_err );
end