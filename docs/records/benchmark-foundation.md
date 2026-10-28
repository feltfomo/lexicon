# Benchmark foundation qualification

The benchmark suite passed its final gate and comparison on 2026-10-28. This record keeps the
identified results that establish calibration, marker overhead and failure handling. Temporary
probes, duplicate captures, function-call maps and raw profiler stacks were discarded.

| Check | Result | Evidence |
| --- | --- | --- |
| Full development gate | exit 0; three tasks succeeded; 1,279 unit cases passed; 586 seconds | [gate log](benchmark-foundation/gate.log) |
| Complete lumi comparison | exit 0; 78 accepted cells within budget; three baseline-only rejections | [comparison](benchmark-foundation/comparison.md), [run identity](benchmark-foundation/run.json) |
| Calibration | 159 accepted cells; all eleven counters deterministic and unchanged | [compact calibration results](benchmark-foundation/calibration.json) |
| Marker overhead | all three Den fleet sizes within calibrated budgets | [overhead report](benchmark-foundation/marker-overhead.md), [run identity](benchmark-foundation/marker-run.json) |
| Current runner control | exit 0; one accepted cell | [smoke report](benchmark-foundation/runner-smoke.md) |
| Incorrect source identity control | expected exit 1; candidate rejected | [rejection report](benchmark-foundation/source-rejection.md) |

## Tested source

The final comparison used baseline `736199d1ecababb0e558eaced2dacf585788a684` and candidate snapshot
`/nix/store/0lhvnz5hn24i869ha2d03wlz6bmzwg8l-source`, with narHash
`sha256-gtUNRktlNb/sCR83noQSB+AByBmOjdFZKEgSEDMS/cw=`. The candidate was recorded as a dirty working
tree at `339c3a8872f51facba1ba0b623124c464589881d`. Its reviewed contents were committed unchanged
as `ac0f9219a9b87404d643b2fccc6039c790222dd6`, then merged as
`71d6f14e4511c383533ad46207a8f0a2eb7943c7`. The merge tree is
`15f8b83c53f9139c47be57dabd7aad7af26c16bd`.

The evaluator was CppNix 2.34.8 at
`/nix/store/hxxgpmyg1g2z1jy063n4fbzvm4y9mk0l-nix-2.34.8`. Lumi's launch check recorded load 1.91,
28,899 MiB available memory and no competing builds or measurements. The final comparison
ran from 03:17 to 03:46 PDT.

The documented gate command was `devenv tasks run lexicon:gate`. Its saved exit was zero and
the log records all three tasks succeeding. A later login-shell logout error affected the outer
command wrapper after the gate completed; it did not change the gate result. No gate rerun was
used to obtain a pass.

## Comparison coverage

The single comparison covered 27 runnable workloads at sizes 4, 16 and 64. Each cell scheduled
two warmups, six alternating counting samples and two separate profiling samples, with a
600-second SIGKILL bound per sample. It completed 783 sample records. Failed samples stopped
their cell; the campaign was not retried.

The three rejected cells were `subsystem.toml.generate` at sizes 4, 16 and 64. Baseline warmup
failed because the baseline did not export `toml.render`. These cells provide no cross-revision
cost comparison. No candidate cell failed and no judged counter regressed. Timing and owner or
marker attribution were reported, not gated; the eleven aggregate counters decided the verdict.

The smoke control used `subsystem.ownerships.resolve` at size 4 through the current runner and
all ten scheduled samples. The negative control copied that capture and changed the source
metadata of candidate sample 3. The report command exited 1 and named the source mismatch. This
was an intentional invalid-record control, not a failure of the final candidate.

## Calibration and retention

The two calibration runs compared clean revision `339c3a8872f51facba1ba0b623124c464589881d` with
itself on lumi. The first covered 81 cells and the second covered 78 subsystem cells. They used
their recorded eight-sample schedules, before separate profiling samples were added.

Before removing scratch, the reviewed Nix record reader, admission rules and calibration owner
were run over both captures again. They accepted all 159 cells and reproduced the committed
[budgets](../../bench/budgets.nix) exactly. Every counter was identical across all three measured
samples on both sides. The compact JSON stores that repeated value once per cell and counter,
alongside both run identities and the validated budget result.

Observed noise was zero. The resulting relative and absolute tolerances are policy floors,
not measured noise: 5 permille and 2,000 counts, or 50 permille and 65,536 bytes for heap bytes.
The [benchmark reference](../../bench/reference.md) documents the method and evaluator limits.

The reports and gate log were copied without rewriting them. The compact calibration record
is a projection of admitted results, not the original statistics. Raw function maps, output
files and folded stacks are not retained, so this bundle cannot independently replay record
admission or reconstruct flame graphs. It preserves the closure results, identities and
calibration quantities; the maintained suite supplies future measurements.

Old partial runs, provisional unjudged reports, copied checkouts, Git bundles and probe scripts
were not closure evidence and were removed with scratch. An earlier derivation-path text file
lacked revision and evaluator metadata, so it was excluded from this evidence bundle. No new
system evaluation or performance campaign was run during cleanup.
