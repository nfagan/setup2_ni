classdef FixationStateTracker < handle
  properties
    ib = false;
    acquired = false;
    ever_acquired = false;
    entered_ts = [];
    exited_ts = [];
    acquired_ts = [];
    t0 = nan;
    first_acquire_callback = [];
    every_acquire_callback = [];
  end
  
  methods    
    function obj = FixationStateTracker(t0, varargin)
      defaults = struct();
      defaults.first_acquire_callback = [];
      defaults.every_acquire_callback = [];
      params = shared_utils.general.parsestruct( defaults, varargin );

      obj.t0 = t0;
      obj.first_acquire_callback = params.first_acquire_callback;
      obj.every_acquire_callback = params.every_acquire_callback;
    end
    
    function [did_break, info] = update(obj, x, y, t, fix_time, targ_rect)
      did_break = false;
      
      info = struct();
      info.ib_t = 0;
      info.ib_entry_t = nan;
      if ( x >= targ_rect(1) && x <= targ_rect(3) && ...
           y >= targ_rect(2) && y <= targ_rect(4) )
        % in bounds
         if ( ~obj.ib )
           obj.entered_ts(end+1) = t;
           obj.ib = true;
         else
           info.ib_t = t - obj.entered_ts(end);
           info.ib_entry_t = obj.entered_ts(end);
         end
         if ( ~obj.acquired && t - obj.entered_ts(end) >= fix_time )
           %  successful acquistiion
           if ( ~obj.ever_acquired && ~isempty(obj.first_acquire_callback) )
             obj.first_acquire_callback();
           end
           if ( ~isempty(obj.every_acquire_callback) )
             obj.every_acquire_callback();
           end
           obj.acquired_ts(end+1) = t;
           obj.acquired = true;
           obj.ever_acquired = true;
         end
      else
        if ( obj.ib )
          obj.exited_ts(end+1) = t;
          obj.ib = false;
          obj.acquired = false;
          did_break = true;
        end
      end
    end
  end
end