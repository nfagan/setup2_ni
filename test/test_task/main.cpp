#include "../../src/task_interface.hpp"
#include "../../src/ni.hpp"
#include <thread>
#include <cstdio>

namespace {

using namespace ni;

} //  anon

int main(int, char**) {
  task::InitParams init_p{};
  init_p.samples_file_p = "C:\\Users\\setup2\\source\\setup2_ni\\data\\test.dat";

  task::start_ni(init_p);

  auto t0 = time::now();
  auto pulse_t0 = time::now();
  while (time::Duration(time::now() - t0).count() < 60.0) {
    task::update_ni();

    auto samp = task::read_latest_sample();
#if 1
    printf("(%0.4f) %0.4f, %0.4f, %0.4f | %0.4f, %0.4f, %0.4f\n",
           samp.sync, samp.pupil1, samp.x1, samp.y1, samp.pupil2, samp.x2, samp.y2);
#endif

#if 0
    if (time::Duration(time::now() - pulse_t0).count() > 2.0) {
#if 1
      for (int i = 0; i < 2; i++) {
        printf("Triggered reward pulse\n");
        task::trigger_reward_pulse(i, 0.5f);
        pulse_t0 = time::now();
      }
#else
      task::trigger_pulse(0, 5.0f, 0.5f);
      printf("Triggered pulse\n");
#endif
    }
#endif

    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }

  task::stop_ni();
}