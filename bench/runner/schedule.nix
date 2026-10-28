# the sampling schedule of one cell. the runner launches it in this order and
# records it in run.json, and the analysis rejects a cell whose samples don't
# follow the recorded schedule. one warm-up per side, then three alternating
# pairs, so drift on the machine lands on both sides. the profile pair comes
# last and runs the profiler alone, since counting and profiling never share a
# process
[
  {
    phase = "warmup";
    side = "baseline";
  }
  {
    phase = "warmup";
    side = "candidate";
  }
  {
    phase = "measure";
    side = "baseline";
  }
  {
    phase = "measure";
    side = "candidate";
  }
  {
    phase = "measure";
    side = "candidate";
  }
  {
    phase = "measure";
    side = "baseline";
  }
  {
    phase = "measure";
    side = "baseline";
  }
  {
    phase = "measure";
    side = "candidate";
  }
  {
    phase = "profile";
    side = "baseline";
  }
  {
    phase = "profile";
    side = "candidate";
  }
]
