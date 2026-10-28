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

`praxis-selected` demands the selected `gate` manifest and `praxis-diagnostics`
demands every `2*N` diagnostic code, authored path and the complete summary.
The sibling `workload.nix` now includes the imported `praxis.nix` fixture and
these validators. An external frozen dispatcher can still be selected with
`--dispatcher /absolute/workload.nix` and one `--bind NAME=SHA256` for it and each
imported file. Names are relative to that directory. Relative or unbound
explicit dispatchers and mismatched bindings exit 2 before evaluation. Bindings
are hashed again after release; drift rejects the sample. The merged observer
retains its instrumentation, record validation and SIGKILL deadline behavior.

`--instrumentation` selects one evaluator mode per process. `none` is ordinary
capture. `flamegraph` adds `--option eval-profiler flamegraph`, a fixed
`eval-profiler-frequency` of 1000 and `eval-profile-file` set to
`<output>/profile.folded`. `counts` sets `NIX_SHOW_STATS=1`, `NIX_COUNT_CALLS=1` and
`NIX_SHOW_STATS_PATH=<output>/stats.json` for the evaluator alone, and passes
`--option eval-profiler disabled`. Sampling and counting never share a process.
In `flamegraph` and `counts`, an inherited `NIX_SHOW_STATS`, `NIX_COUNT_CALLS`,
`NIX_SHOW_STATS_PATH` or `NIX_SHOW_SYMBOLS`, even set to `0`, or a `NIX_CONFIG`
naming the profiler or call tracing exits 2 before launch. Ordinary capture
doesn't check, and passes the caller's environment to the evaluator as it always
has. A caller that needs a clean ordinary sample, such as a profile campaign,
has to clear those variables itself. Instrumentation is refused for the render
phase. The version query after the evaluator never sees the counting variables.

An instrumented sample is admitted only after the ordinary output and exit checks
and a valid record. `profile-contracts.py` owns that decision. The record must be
absent before launch, present afterwards, a regular file owned by this user and
no older than the output directory at launch. It must also parse under the
evaluator's 2.34.8 grammar. Any other evaluator version is unsupported. The
record's `instrumentation` field names the failure as `absent`, `stale`,
`malformed` or `unsupported`. A missing record, an empty profile or statistics
with no counted applications are failures, never an empty result. Wall time and
peak RSS are recorded exactly as for ordinary capture. They aren't primary
acceptance, and they don't estimate overhead to subtract from ordinary samples.

The flamegraph record is folded stacks, one `frame;frame count` line per stack.
Frames print a position as `origin:line:column`, followed by the lambda name,
`functor`, `primop NAME` or `primop derivationStrict:NAME`. The position is
normally the call site, but it isn't always. When the call site's origin doesn't
resolve, a lambda frame prints the lambda's definition and a functor frame
prints its `__functor` attribute. A primop then prints only its name, so a
positioned primop frame is always a call site. The record can't tell the two
lambda cases apart, and `map` labels each frame's `provenance` as `call-site`,
`call-site-or-lambda-definition`, `call-site-or-functor-attribute` or
`unpositioned`. The evaluator only samples when a function is entered and
at least a millisecond has passed since its last sample. Time spent in a primop
or a forced thunk that enters no function is credited to the next stack entered.
The sample map is flushed and cleared every two seconds and again when the
evaluator is destroyed, so a stack can appear on several lines. Their counts are
summed. Samples locate observed execution, not exact cost or the time of first
emission.

`--timeout-seconds` bounds the evaluator with `SIGKILL`, in every mode. `SIGTERM`
wouldn't. Nix turns it into an interrupt flag, and 2.34.8 checks that flag in
I/O, store operations and value printing, never in the evaluation loop, so a
terminated evaluator can keep running and then spend more time unwinding. After
a kill, nothing from teardown is written. A profile keeps only the lines its
two-second flushes wrote before the limit, and statistics are absent. The record
shows `timed_out` and exit `-9`, and the sample is rejected. The observer itself
isn't bounded after the evaluator, for example during the version query, so a
caller with its own deadline bounds the observer's whole process group.

The counts record is the evaluator's statistics JSON. `functions` counts lambda
applications by the lambda's definition position, one per applied argument, and
`primops` counts calls by name. They identify demanded applications at source
positions, not closure instances. Their sums must equal `nrFunctionCalls` and
`nrPrimOpCalls`. The entries must match the writer exactly. Counters and counts
are non-boolean integers, `name` is always present, and `line` and `column`
appear together, with `line` at least 1, only for a positioned lambda. `file` is
added only for a path origin. A positioned entry without `file` and an entry
with no position stay valid. A folded position must print its line and column as
plain integers, never a zero column, because the profiler omits a zero column.
In 2.34.8 `attributes` is always null, because the evaluator
fills a copy of the list, so attribute selection counts aren't available. A
populated list is rejected as a different evaluator. The evaluator runs a full
collection before writing statistics, and the call maps allocate, so counter-mode
wall time and RSS include both. Neither mode gives per-component peak RSS.

`profile-contracts.py qualify --output /absolute/scratch/qualify` runs offline. It
puts a fake `nix` first and only on `PATH`, so no real evaluator starts. It drives
`observe.py` through valid, absent, stale, malformed and unsupported records in
both modes. It also covers a malformed fixture rejected with a valid record, a
timeout, an evaluator that ignores or defers termination in each mode, binding
drift during a run, each pre-launch refusal, the unchanged ordinary command and
ordinary capture with inherited counting or profiler settings. Grammar cases
reject boolean counters, invalid or partial positions and non-canonical frames.
The same command checks source mapping and frame provenance.
`profile-contracts.py map --observation /absolute/sample --roots /absolute/roots.json --output /absolute/frames.json`
maps every positioned frame or counted function to its file, line, byte offset
and line text. Roots are `{"name", "tree", "manifest"?}` directories or
`{"name", "git", "revision"}` repository revisions. A path under a root belongs to
the innermost root. A store-displayed file belongs to the single root whose file
at the same relative path has identical bytes. A fetched input displayed as
`«reference»/path` belongs to the root whose revision or tree that reference
names. Its bytes come from that root, because the display isn't a readable file.
Each mapped position carries `content_sha256`, the hash of the bytes its line
was read from. Line ranges for classification belong to those bytes, never to a
path alone, because the same path holds different code at another revision.
Each origin is read and split once, and every position on it is looked up from
that index. A column of 0 in statistics means none was recorded, so the position
maps to its line start with `column_recorded` false. Line 0, as in `«none»:0`,
is `position-unresolved`. Other outcomes are kept as `unbound`, `ambiguous`,
`stale`, `unreadable`, `unmapped-origin` or a position outside its file or line. Mapping reads displayed
files and Git objects and never writes them. The record has to match its captured
hash first.

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

Praxis selected comparisons use `praxis-selected` and `praxis-diagnostics` at
4, 16 and 64 commands. Each public project contains a selected task referring to
N parameterized namespace commands, an unrelated throwing command and a throwing
namespace sibling. Selected demand reads the complete selected manifest. Diagnostic
demand reads ordered codes, paths and the summary for N invalid argv entries,
without constructing packages. The ordinary `praxis` cell still demands the whole
finite project and stays separate from selected reachability.

`contracts.py --family praxis` retains public callback counts and original
reference/normalization exceptions. These functional observations don't consume
performance workload launches.

The assembled TOML evaluator cell demands the generated derivation's output
identity. The pure renderer changes that derivation, so `compare.py` records both
identities and requires each to stay stable across that source's samples. It
doesn't require identities from different implementations to match. Equal parsed
content, context, build/render costs and closure costs belong to the separately
retained TOML campaign. Every other component requires equal finite JSON output.
