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

The fleet comparison selects `fleet-resolve`, `fleet-prepared`, `fleet-custom`,
`fleet-trace`, `fleet-matrix` and `registry-queries` through `--components`.
Each runs at 4, 16 and 64 names. The same warm-up, three alternating pairs and
fixed noise bounds above apply, including allocations at size 4.

Resolve and prepared fixtures use N hosts, one user, N nested units with two
leaves each, and N contexts. They demand every selected `values` map. Each unit
has an inactive throwing payload. The custom fixture uses one integer-valued
axis and N units, demanding the complete merged map. Trace demands its value,
every leaf key/selection/rejection/check count and stage counts. Matrix demands
all context selections, coverage and host-pair differences, plus dead and dormant
counts; it never demands configuration payloads. Registry declares N hosts and
N users with N memberships each, then performs N usersOn, forSystem, hostsFor and
homeFor queries. Every projected name and home is checked against an independent
expected value in the observer. Bad variants enter actual shape/name validators.

`--initialize-report` first finishes one valid value through the public Program
reporter, then demands the unchanged workload. This sensitivity control exposes
reporter initialization cost. It doesn't replace the uninitialized baseline or
authorize subtracting startup from acceptance measurements.

`snapshot.py --root /absolute/repo --output /absolute/scratch/snapshot` copies
Git-admitted working files, including untracked nonignored files. It verifies
content, file kinds and executable modes against the source before and after
copying, and writes the manifest and identity beside the clean `source` tree.

`contracts.py --source path:/absolute/source --output /absolute/scratch/contracts`
checks real Ownerships factories with callback traces and original exception
text. Prepared translation runs once; ordinary translation remains per context.
Both share stage registration. Leaf and matrix stage callback orders are checked
separately. The probes also cover lazy stage demand, opaque payload/context
transport, left-to-right custom merges and early failure suppression. `--baseline`
uses the original registration counts for the Foundation source. The flake's
`ownerships-observations` check runs these probes with pinned embedded dependency
sources and a dummy store, retaining stdout, stderr and exits in its output.
`--reference /absolute/baseline/contracts` also compares the complete terminal
error text with retained baseline stderr. Callback stack context is checked
separately from that terminal text.

Registered compiler workloads select `compiler-wide`, `compiler-deep`,
`compiler-prepared`, `compiler-dynamic`, `compiler-single` and `compiler-combined`.
Each uses 4, 16 and 64 structural entries or recursive levels. They use an ordinary
registered extension with an Axiom parse callback, a defaulted field, local
metadata and lazy record preparation. Projections check every selected value,
default, metadata value, authored origin and prepared value. Inactive entries
contain throwing payloads; an inactive declared branch contains a throwing callback.

Wide trees compile one collection. Deep trees compile N recursive levels with
an inactive sibling at each nonterminal level. Prepared trees compile N static
entries across N contexts. Dynamic trees produce their collection through a
selected context callback. Single-output demand reads only Home Manager from a
mixed-output block while its resource callback throws. Combined demand reads
Home Manager and NixOS resource bridges with distinct configuration markers.
The observer checks complete finite projections, including external-link sources
and destinations for combined demand. The existing schedule and bounds apply.

`contracts.py --family compiler` checks static and callback-produced registered
trees across two contexts. It counts parse, normalization, metadata, preparation,
collection and lowering callbacks, and checks filtered value/metadata/origin/
preparation alignment. `--reference` compares the complete callback trace order
and terminal exception text with the baseline. Callback, preparation and lowering
exceptions also require their authored demand-site context. The
`declarations-observations` check embeds the pinned sources in an isolated store.

Resource workloads select `resource-directory`, `resource-shared`,
`resource-grouped`, `resource-theme`, `resource-furnish` and `resource-index`.
Sizes count directories, grouped names, theme declarations or Furnish declarations.
The directory source is each admitted snapshot's tracked
`tests/program/fixtures/sample-tree`. Every directory excludes `safe-render.nix`,
reserves inactive `diagnostics.nix`, and selects writable `default.nix`.
Shared demand compiles the same static declaration in N user contexts. Grouped
demand expands two destination roots and includes an opaque ordinary file source.
Theme demand combines N public declaration modules and demands the generated
Matugen registration map. Its generator captures the adapter's input as JSON with
`builtins.toFile`; this measures pure aggregation without a TOML build. Source
paths are omitted from the equal projection, while every destination and output
registration is checked. Furnish demands every compiled identity, target and
executor. Index demand keeps source values, generators and context throwing.
These workloads include evaluation and filesystem inventory reads, excluding
runtime reconciliation, package builds and renderer execution.

Resource output controls reject missing and unsupported projections. Use
`compare.py --stop-on-regression` to stop after the first cell exceeding either
fixed bound. All launched samples remain in its output directory.

`contracts.py --family resources` checks the complete selected resource poison
transport, one real static inventory preparation across two principals, one
materializer across repeated demand, and original provider/materializer exception
text with their Furnish contexts. `--reference` compares terminal exceptions with
retained baseline evidence. The `furnish-observations` flake check runs the same
probes with embedded pinned dependencies and the dummy store. Its retained target
is a supplied plain store string, so callback observation needs no store writes.
The normal `furnish-pure` evaluation separately demands retained string context. Real NixOS module
evaluation in `tests/furnish/runtime.nix` checks disabled, enabled-empty and
nonempty behavior, generated source retention, activation and mount dependencies.

`contracts.py --family terminals` checks public Furnish reporter dispatch and
recovery, theme file group terminals and Matugen group demand. Expected values,
complete diagnostic records and terminal text come from baseline characterization.
Callback events are checked in order, including zero calls to unused methods.
`--reference` also compares terminal text with retained baseline stderr.
`furnish-observations` runs this family alongside resource transport probes.

`toml.py` measures TOML with `--baseline`, `--candidate` and `--output`. Run it
inside the development shell, first for controls and then with `--primary` in a
distinct directory. Use absolute paths and identical dependencies/evaluator.

The fixed sizes are 4, 16 and 64 records. Each contains an integer, precise
float, contextual executable string, heterogeneous array and hexadecimal literal.
Public evaluation demands the generated derivation path and context. Build
samples realize the complete file, using `--rebuild` after warm-up. CLI samples
invoke each installed package on the same prepared encoding. Every rendered
file is parsed and compared with the finite fixture, including its executable
path.

Candidate-only pure samples demand text, literal metadata and context. Prepared
JSON is decoded and executable fields receive the original context before
rendering. These samples include decoding and context attachment, exclude encoder
application validation, and have no baseline renderer comparison. Public generate
evaluation includes both encoding and rendering.

Comparable cells use one warm-up per side and three alternating pairs, with the
wall/RSS bounds above. Wall time covers launch through reaping. CLI RSS uses
Linux wait4 process-family accounting. Nix statistics are enabled for both sides;
candidate CLI child statistics establish its evaluator invocation. Observer cost
is included, never subtracted. Daemon/builder RSS is excluded. Closure records
retain all paths, NAR sizes, shared bytes and bytes exclusive to either side.

Controls cover valid/invalid application input, generated-file opacity with IFD
disabled, installed generation, contextual pure output, a missing source and a
forced timeout. Expected failures remain in their directories. Stop on invalid
controls, output/context/identity mismatch, unreleased processes or regression.
The controls and primary schedule use at most 122 evaluator/CLI launch units,
including package setup and each candidate CLI's child. Closure queries are
recorded separately. The schedule is expected to take minutes; thirty minutes
or more requires readiness review.
