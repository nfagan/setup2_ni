classdef AsyncVideoInterface < handle
  properties (Constant = true)
    INITIAL_TIMEOUT = 60;
    VIDEO_ERROR_FILE_PREFIX = 'video_error';
  end

  properties (Access = private)
    FRAME_RATE;
  end

  properties (SetAccess = private)
    initialized = false;
    dummy = false;
    video_writer_output_p = '';
    serial = false;
    max_duration = [];
  end

  properties (Access = private)
    par_future = [];
    serial_result = [];
    cached_result = [];
  end

  methods
    function obj = AsyncVideoInterface(dummy, dst_p, serial, max_duration)
      if ( nargin < 3 || isempty(serial) )
        serial = false;
      end
      if ( nargin < 4 )
        max_duration = [];
      end

      validateattributes( dummy, {'logical'}, {'scalar'}, mfilename, 'dummy' );
      validateattributes( dst_p, {'char'}, {'scalartext'}, mfilename, 'dst_p' );
      validateattributes( serial, {'logical'}, {'scalar'}, mfilename, 'serial' );
      obj.dummy = dummy;
      obj.video_writer_output_p = dst_p;
      obj.serial = serial;
      obj.max_duration = max_duration;

      % @NOTE: The video cameras trigger at half the rate of the counter
      % output pulse.
%       obj.FRAME_RATE = NIInterface.get_sync_pulse_hz() * 0.5;
      obj.FRAME_RATE = NIInterface.get_sync_pulse_hz();
    end

    function initialize(obj)
      shutdown( obj );

      ParallelErrorChecker.clear_error( AsyncVideoInterface.VIDEO_ERROR_FILE_PREFIX );

      if ( obj.dummy )
        return
      end

      cb = @() do_capture(...
        obj.FRAME_RATE, obj.video_writer_output_p, obj.INITIAL_TIMEOUT, obj.max_duration);

      if ( obj.serial )
        obj.serial_result = cb();
      else
        obj.par_future = parfeval( cb, 1 );
      end

      obj.initialized = true;
    end

    function res = get_saveable_data(obj)
      wait( obj );
      res = obj.cached_result;
    end

    function res = wait(obj)
      res = [];

      if ( ~obj.initialized )
        return
      end

      if ( ~isempty(obj.serial_result) )
        % serial
%         assert( isempty(obj.par_future) );
        res = obj.serial_result;
        obj.serial_result = [];
      else
        % parallel
%         assert( ~isempty(obj.par_future) );
        wait( obj.par_future );

        if ( ~isempty(obj.par_future.Error) )
          warning( obj.par_future.Error.message );
        end

        try
          res = fetchOutputs( obj.par_future );
        catch err
          fprintf( '\n Err: %s', err.message );
        end
        delete( obj.par_future );
        obj.par_future = [];
      end

      if ( ~isempty(res) )
        obj.cached_result = res;
      end
    end
    
    function shutdown(obj)
      obj.serial_result = [];

      if ( ~isempty(obj.par_future) )
        delete( obj.par_future );
      end

      obj.initialized = false;
    end

    function delete(obj)
      shutdown( obj );
    end
  end
end

function res = do_capture(frame_rate, dst_p, init_timeout, max_duration)

res = [];
success = true;
% for debugging parallel error signaler.
debug_throw_err = false;

try

% When this amount of time has elapsed with no new frames available, 
% capture will be stopped.
ACQ_TIMEOUT = 5;

[vi1, vw1, vs1] = make_components( 1, frame_rate, dst_p );
[vi2, vw2, vs2] = make_components( 2, frame_rate, dst_p );

start( vi1 );
start( vi2 );

t0 = tic();
last_t = nan;
vi1_has_frames = true;
vi2_has_frames = true;

while ( ~vi1.FramesAvailable || ~vi2.FramesAvailable )
  if ( ParallelErrorChecker.has_error(TaskInterface.TASK_ABORTED_FILE_PREFIX) )
    success = false;
    break
  end
  if ( isnan(last_t) || toc(t0) - last_t > 0.25 )
    fprintf( '\n Waiting for frames' );
    last_t = toc( t0 );
  end
  if ( toc(t0) > init_timeout )
    vi1_has_frames = vi1.FramesAvailable;
    vi2_has_frames = vi2.FramesAvailable;
    success = false;
    break
  end
end

if ( success )
  fprintf( '\n Began' );
  
  t = tic;
  acq_t = tic;
  start_t = tic;
  while ( true )
    drawnow;

    if ( toc(acq_t) > 8 && debug_throw_err )
      error( 'Example error in video acquisition' );
    end

    if ( ParallelErrorChecker.has_error(TaskInterface.TASK_ABORTED_FILE_PREFIX) )
      break
    end
  
    if ( ~isempty(max_duration) && toc(start_t) >= max_duration )
      fprintf( '\n Max duration of recording reached.' );
      break

    elseif ( vi1.FramesAvailable || vi2.FramesAvailable )
      t = tic;

    elseif ( toc(t) > ACQ_TIMEOUT )
      fprintf( '\n No frames received within %0.3f s; stopping acquisition.' ...
        , ACQ_TIMEOUT );
      break
    end
  end
else
  ParallelErrorChecker.set_error( ...
    AsyncVideoInterface.VIDEO_ERROR_FILE_PREFIX ...
    , sprintf(['Failed to start capturing frames within %0.3f s\n' ...
    ,  'Cam 1 had frames? %d | Cam 2 had frames? %d'] ...
    , init_timeout, double(vi1_has_frames), double(vi2_has_frames)));
end
  
stop( vi1 );
stop( vi2 );

delete( vi1 );
delete( vi2 );

if ( ~isempty(vw1) )
  release( vw1 ); 
end
if ( ~isempty(vw2) )
  release( vw2 );
end

if ( success )
  res = struct();
  res.vs1 = vs1;
  res.vs2 = vs2;
end

catch err
  ParallelErrorChecker.set_error( ...
    AsyncVideoInterface.VIDEO_ERROR_FILE_PREFIX, err.message );
end

imaqreset;

end

function [vi1, vid_writer1, vid_sync1] = make_components(index, frame_rate, vid_p)

vi1 = videoinput( 'gentl', index );

vi_src = getselectedsource( vi1 );

set( vi_src, 'TriggerMode', 'On' );
set( vi_src, 'TriggerSource', 'Line3' );

if ( 1 )
  set( vi1, 'ROIPosition', [0, 0, 320, 256] );
end

triggerconfig( vi1, 'hardware', 'DeviceSpecific' );

% set_exposure_time_from_fps( vi1, frame_rate, 1e3 );

% video writer
vid_fname = sprintf( 'video_%d.mp4', index );

if ( isempty(vid_p) )
  vid_writer1 = [];
else
  vid_writer1 = vision.VideoFileWriter( fullfile(vid_p, vid_fname) );
  set( vid_writer1, 'FrameRate', frame_rate );
  set( vid_writer1, 'FileFormat', 'MPEG4' );
end

% vid sync
vid_sync1 = make_vid_sync();

% vi config
vi1.FramesAcquiredFcn = ...
  @(src, obj) save_images(vid_writer1, vid_fname, vid_sync1, src, obj);
vi1.FramesAcquiredFcnCount = 1;
vi1.Timeout = 30;
vi1.TriggerRepeat = inf;

end

function s = make_vid_sync()

s = ptb.Reference( struct );
s.Value.vid_time = [];
s.Value.frame_num = [];
s.Value.vid_fname = strings( 0 );

end

function save_images(vid_writer, vid_name, vid_sync, src, cb_data)   

imgs = getdata( src, src.FramesAvailable );
fprintf( '\n Writing images into %s; size: %d %d' ...
  , vid_name, size(imgs, 1), size(imgs, 2) );

if ( ~isempty(vid_writer) )
  try
    for i = 1:size(imgs, 4)
      step( vid_writer, imgs(:, :, :, i) );
    end
  catch err
    warning( err.message );
  end
end

vid_sync.Value.vid_time(end+1, :) = cb_data.Data.AbsTime;
vid_sync.Value.frame_num(end+1, 1) = cb_data.Data.FrameNumber;
vid_sync.Value.vid_fname(end+1, 1) = string( vid_name );

end

function set_exposure_time_from_fps(vid1, fps, pad_us)

src = getselectedsource( vid1 );
desired_exposure_time_us = (1 / fps) * 1e6 - pad_us;
set( src, 'ExposureTime', desired_exposure_time_us );

end
