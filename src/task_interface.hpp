#pragma once

#include <string>

namespace ni::task {

struct InitParams {
  std::string samples_file_p;
};

struct Sample {
  float pupil1;
  float x1;
  float y1;
  float pupil2;
  float x2;
  float y2;
  float sync;
};

struct MetaInfo {
  float sync_pulse_init_timeout_s;
  double sync_pulse_hz;
  double sample_rate;
};

struct RunInfo {
  int min_num_sample_buffers;
  bool any_dropped_sample_buffers;
  uint64_t num_input_samples_acquired;
};

void start_ni(const InitParams& params);
void update_ni();
RunInfo stop_ni();
Sample read_latest_sample();
void trigger_reward_pulse(int channel_index, float secs);
void trigger_pulse(int channel_index, float v, float secs);
MetaInfo get_meta_info();

}