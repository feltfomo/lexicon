# one sample's demanded value. the catalog always comes from the candidate's
# snapshot and the lexicon under test from the side's locked reference, so both
# sides run identical workload code against their own library
{
  bench,
  source,
  workload,
  size,
  system,
}:
(import (bench + "/workloads")).project {
  project = builtins.getFlake source;
  name = workload;
  inherit size system;
}
