# Component measurements

Run these tools inside the documented development shell with an explicitly
selected Nix evaluator. `observe.py` runs one actual public workload, writes its
stdout, stderr and record, and admits it only after exit zero and output validation.
`compare.py` runs the fixed comparison schedule. Neither tool changes HOME.

Workload sizes are 4, 16 and 64. Ownerships resolves that many selected units;
Registry summarizes that many hosts; declarations demand that many native fields;
resources lower that many links; TOML evaluates that many integer fields; Praxis
demands a manifest containing that many commands. Projections exclude opaque
module internals, callbacks and unrelated output branches.

Each cell warms both sources once, then runs three pairs in baseline/candidate,
candidate/baseline, baseline/candidate order. Samples use the same evaluator and
projection. Output mismatches, unsuccessful exits and unreleased evaluator
processes stop the batch. No samples are discarded. Median noise bounds are fixed
before candidate measurements at 35% plus 0.03 wall seconds and 25% plus 8192 KiB
RSS. Exceeding a bound is reported, not retried or hidden.

Wall seconds cover process launch through reaping the evaluator. Peak RSS is the
evaluator process's Linux `wait4` maximum in KiB. It excludes daemon and builder
memory. Output bytes count the finite JSON projection. The record retains the
structural count, evaluator version, command and output hash. This observes the
component's public path including dependency setup, not an isolated algorithm.

TOML's default phase measures evaluation to its output path. Run `observe.py` with
`--component toml --phase render` separately to realize the artifact and validate
its parsed content. That phase records render wall time and rendered bytes, plus
closure size in bytes and a separately timed closure query. Cached realization is
explicitly possible; it isn't pure renderer timing.

Use absolute paths for source snapshots and distinct output directories. For example,
`python3 verification/components/observe.py --source path:/absolute/source --component ownerships --size 4 --output /absolute/scratch/sample`.
`compare.py` accepts `--baseline`, `--candidate` and `--output`.

Before a comparison, run valid and `--bad` inputs for all components. Bad inputs
reach their actual validators. Exercise a missing source and a deliberately short
`--timeout-seconds` limit, checking rejected records and process release. Unsupported
components, sizes and render combinations exit 2 before launching an evaluator.
The effects fixture separately contrasts raw and thunk-protected poison state.
Retain failed controls and correct their cause before starting comparisons.

Use a quiet machine with no concurrent builds. The small default batch has 144
evaluations and is expected to finish in minutes. A larger campaign needs a fresh
readiness review. Preserve source manifests with the evidence; local dependency
overrides establish provisional integration only.
