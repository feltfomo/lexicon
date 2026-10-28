# the sampling schedule of one cell. the runner launches it in this order and
# the analysis rejects a cell whose samples don't follow it, so both read it here.
# one warm-up per side, then three alternating pairs, so drift on the machine
# lands on both sides
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
]
