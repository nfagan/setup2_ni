function [fs_m1, fs_m2] = static_fixation2(...
    time_cb, draw_cb ...
  , targ_loc_cb1, pos_cb1 ...
  , targ_loc_cb2, pos_cb2, loop_cb ...
  , fix_time, state_time, abort_on_break ...
  , varargin)

if ( nargin < 10 || isempty(abort_on_break) )
  abort_on_break = true;
end

defaults = struct();
defaults.m1_first_acq_callback = [];
defaults.m2_first_acq_callback = [];
defaults.m1_every_acq_callback = [];
defaults.m2_every_acq_callback = [];
params = shared_utils.general.parsestruct( defaults, varargin );

entry_t = time_cb();

fs_m1 = FixationStateTracker( entry_t ...
  , 'first_acquire_callback', params.m1_first_acq_callback ...
  , 'every_acquire_callback', params.m1_every_acq_callback ...
);
fs_m2 = FixationStateTracker( entry_t ...
  , 'first_acquire_callback', params.m2_first_acq_callback ...
  , 'every_acquire_callback', params.m2_every_acq_callback ...
);

while ( time_cb() - entry_t < state_time && ~(fs_m1.acquired && fs_m2.acquired) )
  loop_cb();
  
  if ( ~isempty(draw_cb) )
    draw_cb();
  end
  
  m1_xy = pos_cb1();
  m2_xy = pos_cb2();
  
  targ_rect1 = targ_loc_cb1();
  targ_rect2 = targ_loc_cb2();
  
  t = time_cb();
  
  m1_broke = update( fs_m1, m1_xy(1), m1_xy(2), t, fix_time, targ_rect1 );
  m2_broke = update( fs_m2, m2_xy(1), m2_xy(2), t, fix_time, targ_rect2 );
  
  % 10/20/2023 GY
  if ( abort_on_break && (m1_broke && m2_broke) )
    break
  end


%   if ( abort_on_break && (m1_broke || m2_broke) )
%     break
%   end
end

end