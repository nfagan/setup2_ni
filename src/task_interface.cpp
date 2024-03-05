#ifdef DUMMY_NI

#include "task_interface_dummy.cpp"

#else

#include "task_interface.hpp"
#include "ni.hpp"
#include "ringbuffer.hpp"
#include <thread>
#include <memory>
#include <fstream>
#include <iostream>
#include <mutex>
#include <cassert>

namespace ni {

namespace {

/*
 * Config
 */

struct Config {
  static constexpr double sample_rate = 10000.0;
  static constexpr int num_samples_per_channel = 5;
  static constexpr double sync_pulse_hz = 90.0;
  //  @NOTE: This is the time between initializing the sync pulse counter
  //  output task and the pulse train beginning. This amount of time must
  //  be longer than the time required to initialize / prepare any receivers
  //  of this pulse (e.g., cameras), and will probably have to be experimentally
  //  determined.
  static constexpr double sync_pulse_init_timeout_s = 15.0;
  static constexpr double sync_pulse_term_timeout_s = 10.0;
};

/*
 * types
 */

struct OutputStream {
  std::ofstream stream;
};

struct FromTask {
  void clear() {
    latest_sample = {};
  }

  task::Sample latest_sample{};
  mutable std::mutex mutex;
};

struct ToTask {
public:
  struct PulseCommand {
    int channel;
    float seconds;
    bool is_custom_voltage;
    float custom_voltage;
  };
public:
  void clear() {
    pulses.clear();
    pending_pulses.clear();
  }

  RingBuffer<PulseCommand, 4> pulses;
  std::vector<PulseCommand> pending_pulses;
};

/*
 * globals
 */

struct {
  std::unique_ptr<std::thread> task_thread{};
  std::atomic<bool> task_thread_keep_processing{};
  OutputStream samples_file;

  FromTask from_task;
  ToTask to_task;
  task::RunInfo run_info{};
} globals;

/*
 * anon procs
 */

task::Sample construct_task_sample_from_sample_buffer(const ni::SampleBuffer& buff) {
  if (buff.num_samples() == 0) {
    return {};
  }

  assert(buff.num_channels == 7);

  const int latest_sample_index = (buff.num_samples_per_channel - 1) * buff.num_channels;
  task::Sample sample{};
  sample.x1 =     float(buff.data[latest_sample_index + 0]);
  sample.y1 =     float(buff.data[latest_sample_index + 1]);
  sample.pupil1 = float(buff.data[latest_sample_index + 2]);
  sample.x2 =     float(buff.data[latest_sample_index + 3]);
  sample.y2 =     float(buff.data[latest_sample_index + 4]);
  sample.pupil2 = float(buff.data[latest_sample_index + 5]);
  sample.sync=    float(buff.data[latest_sample_index + 6]);
  return sample;
}

bool open_output_stream(OutputStream* stream, const char* file_p) {
  stream->stream.open(file_p, std::ios::binary);
  return stream->stream.good();
}

void flush_output_stream(OutputStream* stream) {
  if (stream->stream.good()) {
    stream->stream.flush();
  }
}

void write_output_stream(OutputStream* stream, const ni::SampleBuffer& buff) {
  try {
    stream->stream.write((char*) buff.data, buff.num_samples() * sizeof(double));
  } catch (...) {
    std::cerr << "Failed to write to output stream." << std::endl;
  }
}

void send_from_task(FromTask* from_task, const ni::SampleBuffer* buffs, int num_buffs) {
  if (num_buffs > 0) {
    std::lock_guard<std::mutex> lock{from_task->mutex};
    from_task->latest_sample = construct_task_sample_from_sample_buffer(buffs[num_buffs - 1]);
  }
}

void send_to_task(ToTask* to_task) {
  auto it = to_task->pending_pulses.begin();
  while (it != to_task->pending_pulses.end()) {
    if (!to_task->pulses.maybe_write(*it)) {
      break;
    } else {
      it = to_task->pending_pulses.erase(it);
    }
  }
}

void push_pending_ttl_pulse(ToTask* to_task, int channel, float secs) {
  ToTask::PulseCommand cmd{};
  cmd.channel = channel;
  cmd.seconds = secs;
  to_task->pending_pulses.push_back(cmd);
}

void push_pending_custom_pulse(ToTask* to_task, int channel, float v, float secs) {
  ToTask::PulseCommand cmd{};
  cmd.channel = channel;
  cmd.seconds = secs;
  cmd.custom_voltage = v;
  cmd.is_custom_voltage = true;
  to_task->pending_pulses.push_back(cmd);
}

task::Sample read_sample(const FromTask* from_task) {
  std::lock_guard<std::mutex> lock{from_task->mutex};
  return from_task->latest_sample;
}

bool task_init_ni() {
  const double minv = -5.0;
  const double maxv = 5.0;

  ni::ChannelDescriptor ai_channel_descs[7]{
    {"dev1/ai0", minv, maxv},  //  x1
    {"dev1/ai1", minv, maxv},  //  y1
    {"dev1/ai2", minv, maxv},  //  pup1
    {"dev1/ai3", minv, maxv},  //  x2
    {"dev1/ai4", minv, maxv},  //  y2
    {"dev1/ai5", minv, maxv},  //  pup2
    {"dev1/ai6", minv, maxv},  //  sync pulse feedback
  };

  ni::ChannelDescriptor ao_channel_descs[2]{
    {"dev1/ao0", minv, maxv},  //  juice1
    {"dev1/ao1", minv, maxv},  //  juice2
  };

  ni::CounterOutputChannelDescriptor co_channel_descs[1]{
    {"dev1/ctr0", Config::sync_pulse_init_timeout_s, Config::sync_pulse_hz, 0.5}
  };

  ni::InitParams params{};
  params.sample_rate = Config::sample_rate;
  params.num_samples_per_channel = Config::num_samples_per_channel;
  params.analog_input_channels = ai_channel_descs;
  params.num_analog_input_channels = 7;
  params.analog_output_channels = ao_channel_descs;
  params.num_analog_output_channels = 2;
  params.counter_output_channels = co_channel_descs;
  params.num_counter_output_channels = 1;
  return init_ni(params);
}

//  write samples to disk
void task_write_data(const ni::SampleBuffer* buffs, int num_buffs) {
  for (int i = 0; i < num_buffs; i++) {
    const ni::SampleBuffer& buff = buffs[i];
    write_output_stream(&globals.samples_file, buff);
  }
}

//  send data to main thread
void task_send(const ni::SampleBuffer* buffs, int num_buffs) {
  send_from_task(&globals.from_task, buffs, num_buffs);
}

//  trigger pending pulses
void task_trigger_pulses() {
  const int num_pend = globals.to_task.pulses.size();
  for (int i = 0; i < num_pend; i++) {
    ToTask::PulseCommand pulse = globals.to_task.pulses.read();

    bool err{};
    if (pulse.is_custom_voltage) {
      err = !ni::write_analog_pulse(pulse.channel, pulse.custom_voltage, pulse.seconds);
    } else {
      err = !ni::write_analog_pulse(pulse.channel, true, pulse.seconds);
    }

    if (err) {
      printf("Warning: failed to write analog pulse to channel: %d\n", pulse.channel);
    }
  }
}

//  flush pending buffers to disk
void task_flush_data() {
  const ni::SampleBuffer* buffs{};
  const int num_buffs = ni::read_sample_buffers(&buffs);
  task_write_data(buffs, num_buffs);
  flush_output_stream(&globals.samples_file);
}

//  task loop
void task_loop() {
  update_ni();

  const ni::SampleBuffer* buffs{};
  const int num_buffs = ni::read_sample_buffers(&buffs);

  task_write_data(buffs, num_buffs);
  task_send(buffs, num_buffs);
  task_trigger_pulses();
}

//  main task thread
void task_thread(const task::InitParams& params) {
  if (!open_output_stream(&globals.samples_file, params.samples_file_p.c_str())) {
    return;
  }

  if (task_init_ni()) {
    while (globals.task_thread_keep_processing.load()) {
      task_loop();
    }

    //  terminate counter outputs
    ni::terminate_ni_counter_output_tasks();

    //  then wait for pulse train to finish
    auto t0 = time::now();
    while (time::Duration(time::now() - t0).count() < Config::sync_pulse_term_timeout_s) {
      task_loop();
    }
  }

  auto ni_res = terminate_ni([]() {
    task_flush_data();
  });

  globals.run_info.any_dropped_sample_buffers = ni_res.any_dropped_sample_buffers;
  globals.run_info.min_num_sample_buffers = ni_res.min_num_sample_buffers;
  globals.run_info.num_input_samples_acquired = ni_res.num_input_samples_acquired;
}

} //  anon

void task::start_ni(const task::InitParams& params) {
  stop_ni();

  globals.task_thread_keep_processing.store(true);
  globals.task_thread = std::make_unique<std::thread>([params] {
    task_thread(params);
  });
}

void task::update_ni() {
  send_to_task(&globals.to_task);
}

task::RunInfo task::stop_ni() {
  globals.task_thread_keep_processing.store(false);
  if (globals.task_thread) {
    globals.task_thread->join();
    globals.task_thread = nullptr;
  }

  const task::RunInfo result = globals.run_info;
  globals.from_task.clear();
  globals.to_task.clear();
  globals.samples_file = {};
  globals.run_info = {};
  return result;
}

task::Sample task::read_latest_sample() {
  return read_sample(&globals.from_task);
}

void task::trigger_reward_pulse(int channel_index, float secs) {
  push_pending_ttl_pulse(&globals.to_task, channel_index, secs);
  send_to_task(&globals.to_task);
}

void task::trigger_pulse(int channel_index, float v, float secs) {
  push_pending_custom_pulse(&globals.to_task, channel_index, v, secs);
  send_to_task(&globals.to_task);
}

task::MetaInfo task::get_meta_info() {
  task::MetaInfo result{};
  result.sync_pulse_init_timeout_s = Config::sync_pulse_init_timeout_s;
  result.sync_pulse_hz = Config::sync_pulse_hz;
  result.sample_rate = Config::sample_rate;
  return result;
}

} //  ni

#endif  //  #ifdef DUMMY_NI