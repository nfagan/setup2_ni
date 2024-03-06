classdef TransformNIGazeCoordinates < handle
  properties
    calibration_rect_m1 = [0, 0, 1280, 1024];
    calibration_rect_m2 = [0, 0, 1280, 1024];
  end
  
  properties (Constant = true)
    vlims = [-5, 5];
    padding_frac = [0.2, 0.2];
  end

  methods
    function set_rect_m1(obj, r)
      obj.calibration_rect_m1 = r;
    end

    function set_rect_m2(obj, r)
      obj.calibration_rect_m2 = r;
    end

    function r = padded_rect_m1(obj)
      r = padded_rect( obj.calibration_rect_m1, obj.padding_frac );
    end

    function r = padded_rect_m2(obj)
      r = padded_rect( obj.calibration_rect_m2, obj.padding_frac );
    end

    function [x, y] = scale_coords_m1(obj, x, y)
      vlims = TransformNIGazeCoordinates.vlims;
      padding_frac = TransformNIGazeCoordinates.padding_frac;
      calib_rect = obj.calibration_rect_m1;
      [x, y] = transform_gaze_coords( x, y, vlims, calib_rect, padding_frac );
    end

    function [x, y] = scale_coords_m2(obj, x, y)
      vlims = TransformNIGazeCoordinates.vlims;
      padding_frac = TransformNIGazeCoordinates.padding_frac;
      calib_rect = obj.calibration_rect_m2;
      [x, y] = transform_gaze_coords( x, y, vlims, calib_rect, padding_frac );
    end
  end
end

function r = padded_rect(r, padding_frac)

w = diff( r([1, 3]) );
h = diff( r([2, 4]) );

w = w + w * padding_frac(1);
h = h + h * padding_frac(2);

cx = mean( r([1, 3]) );
cy = mean( r([2, 4]) );

r = [ cx - w * 0.5, cy - h * 0.5, cx + w * 0.5, cy + h * 0.5 ];

end

function [x, y] = transform_gaze_coords(vx, vy, vlims, base_rect, padding_frac)

% r = [x1, y1, x2, y2];
x1 = base_rect(1);
x2 = base_rect(3);
y1 = base_rect(2);
y2 = base_rect(4);

w = x2 - x1;
h = y2 - y1;

expand_lb_x = w * padding_frac(1);
expand_ub_x = w * padding_frac(2);

expand_lb_y = h * padding_frac(1);
expand_ub_y = h * padding_frac(2);

x_range = [x1 - expand_lb_x, x2 + expand_ub_x];
y_range = [y1 - expand_lb_y, y2 + expand_ub_y];

fx = (vx - vlims(1)) ./ (vlims(2) - vlims(1));
fy = (vy - vlims(1)) ./ (vlims(2) - vlims(1));

x = (x_range(2) - x_range(1)) * fx + x_range(1);
y = (y_range(2) - y_range(1)) * fy + y_range(1);

end