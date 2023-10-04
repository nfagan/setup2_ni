task_data_p = 'C:\Users\setup2\source\setup2_ni\task\data';
npxi_data_p = 'C:\Users\setup2\Documents\Open Ephys\data\test';

npxi_sesh = '2023-10-04_17-49-39';
npxi_exper = 'experiment5/recording1';
task_sesh = 'latest';

if ( strcmp(task_sesh, 'latest') )
  task_seshs = shared_utils.io.filenames( ...
    shared_utils.io.find(task_data_p, 'folders') );
  task_sesh = datetime( strrep(task_seshs, '_', ':') );
  [~, mi] = max( task_sesh );
  task_sesh = task_seshs{mi};
end

task_data_p = fullfile( task_data_p, task_sesh );
npxi_data_p = fullfile( ...
  npxi_data_p, npxi_sesh ...
  , 'Record Node 101', npxi_exper, 'continuous\Neuropix-PXI-100.ProbeA-AP' ...
);

validate_npxi_video_sync( ...
    fullfile(task_data_p, 'video_1.mp4') ...
  , fullfile(task_data_p, 'video_2.mp4') ...
  , fullfile(task_data_p, 'ni.bin') ...
  , fullfile(npxi_data_p, 'continuous.dat') ...
);