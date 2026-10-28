# Praxis diagnostic initialization sensitivity

The initialized size-4 and size-64 cells completed on 2026-10-25 and exceeded the unchanged
wall and peak evaluator RSS bounds. Finishing an empty successful public report
before demanding diagnostics was insufficient for this frozen candidate. The
experiment stopped during raw size 64 when a foreign `nix` process appeared at a
release check. Raw size 64 has no complete median comparison.

This is a bounded diagnostic result. It does not establish a dependency cause, unavoidable cost
or accepted cost exception. The stopped cell has no complete median comparison.

## Question and method

The competing explanations were public report-policy/handler setup, first-emission
initialization and workload-dependent validation, adaptation or re-emission.
Source inspection and retained functional qualification didn't separate them.
The finite experiment tested sensitivity to the maintained workload's public
empty-success report pre-demand. It did not introduce a new diagnostic path.

The approved schedule contained three distinct cells in this order:

| Component | Size | Public report initialization | Scheduled launches | Actual launches | Campaign-admitted samples |
| --- | --- | --- | --- | --- | --- |
| `praxis-diagnostics` | 4 | Enabled | 8 | 8 | 8 |
| `praxis-diagnostics` | 64 | Enabled | 8 | 8 | 8 |
| `praxis-diagnostics` | 64 | Disabled | 8 | 5 | 4 |

Each cell scheduled one warmup per source, then three pairs ordered
baseline/candidate, candidate/baseline, baseline/candidate. Warmups count toward
launch and cost totals and don't enter medians. Cell identity includes component,
size and initialization flag. There were no additional controls or retries.

The maintained dispatcher initializes by demanding
`(api.report { }).finish { diagnostics = [ ]; value = true; }` before returning
the unchanged workload projection. That demand remains inside the measured
evaluator process. An empty successful report doesn't emit a diagnostic and
doesn't establish that every native type allocation or first-emission path was
initialized or shared.

The Praxis fixture declares N parameterized namespace commands reached through
the selected `gate` task. Invalid argv entries produce the ordered `2*N`
`praxis/args-shape` codes, authored paths `[0]` and complete summary. The unrelated
command and namespace sibling remain throwing. Diagnostics and summaries don't
construct packages. Demand, declarations, public factories, overrides, extension
contracts, diagnostic order, failure boundaries and lazy thunk transport were
unchanged. This phase changed no production source or maintained tool.

Wall seconds cover evaluator launch through `wait4` reaping. Peak RSS is that
evaluator's Linux maximum in KiB, excluding daemon and builder memory. The
observer retains complete stdout and stderr, output bytes and SHA-256, exit,
command, initialization flag, wall time, peak RSS, admission and evaluator
release. The runner separately records observer reaping, observer-group absence
and host admission/release observations before admitting a sample to comparisons.

The bounds remained candidate wall median <= baseline median * 1.35 + 0.03
seconds and candidate peak RSS median <= baseline median * 1.25 + 8192 KiB.
Bound misses were diagnostic outcomes in this sensitivity. Semantic, control,
identity, output, metric, release, foreign-workload or time failures stopped the
attempt. Evaluators were bounded at 60 seconds and the runner at 600 seconds.
No setup subtraction, tracing, reduced demand, source override, production
priming or successful-check bypass was used.

## Measurement identities

The measurement basis was `b370ee14c7d272c7b11106210dd2ee4b16034576`. The frozen
candidate and immediate baseline are identified separately below.

| Input | Identity |
| --- | --- |
| Frozen candidate | `praxis-production-integration/final-candidate/source` |
| Candidate canonical 356-file content/kind/executable manifest SHA-256 | `4bd1bd91e8ae08bb07120b8039d8bebb755020568567a06c9579204c6d03bbe1` |
| Candidate lock SHA-256 | `5677cbb7fb467a68922190375bbcb9b48e8850a87d6d1930a029de5926b4107e` |
| Immediate baseline | `praxis-final/immediate`, revision `11204c6592fdf4693075d08f44115751c3cc7881` |
| Immediate baseline lock SHA-256 | `0becfd8dc0e64bd9269e44198379e6affb1c2610f155e0d5076b35838b02d2e1` |
| Krisis | Clean checkout at `c48e40834fe90299096d2988433b17f650c30c8a`; qualified Fx unchanged |
| Evaluator | Nix 2.34.8, binary SHA-256 `f7eaf4e186b1a1baa9ac5f5c21dfc3226436e703e7e92b830ca62758ded9e84b` |
| Python observer runtime | 3.14.8, binary SHA-256 `5c4a05f602b2e901adf6065899af4659229fb7e1290d6da3c3eb8f07e9a1f4a5` |
| Frozen observer SHA-256 | `f4184e3f4df637f7baf99d97084e4b74cc62ea1bdf4c5790a4f5336d584d1b32` |
| Frozen dispatcher SHA-256 | `80373f43e545962798cd49553f69284e5da64c917f04c67ecc9495202cfc0244` |
| Frozen Praxis fixture SHA-256 | `3fa7155e9a8a53731f19fb1120665c44ceab5d9c19931d442aa91c41e407a98f` |
| Reviewed readiness SHA-256 | `8e217b02be9ce8a0ae3b9da058c0f825fafcefae89390c82a06a1d67bccc9e5d` |
| Reviewed `identities.json` SHA-256 | `c13469090fe81cd91b9f8b4b3f3be7f6a6eb023c558f8e67577b522fbb0985e7` |

The evaluator was selected through the documented development shell, whose locked nixpkgs
identity matched the frozen candidate.

Before launch, readiness bound every observer command, complete evaluator
expression, source, initialization flag and output destination. Each evaluator
used `nix eval --impure --json --option allow-import-from-derivation false
--extra-experimental-features pipe-operators --expr` with its recorded expression.
The observer used its unchanged default evaluation phase and output projection,
size 4 or 64, timeout 60, and `--initialize-report` only for initialized cells.

The execution environment was khion, native x86_64 Linux, with systemd as PID 1 in
`pid:[4026531836]`. `toolchain.json` retains the full PATH, Python version and Nix
environment; readiness binds stable Nix variables and configuration-file hashes.
`NIX_BUILD_CORES` was `8`. Invocation-local shell directory, root, logging
descriptor and nesting variables were recorded separately. Cache and feature
configuration was inherited, with ordinary prescribed warmups and no cache reset
or additional priming. The inherited unknown-feature warnings remain in complete
stderr. The initial identity-only shell capture's exit status wasn't retrieved;
its identity file was verified. No fresh preparatory version query was issued.

The campaign was bounded to 24 workload attempts and 25 metadata queries. The prelaunch
language-server check found no candidates and sent no signals.

## Completed comparisons

These medians exclude the two warmups in each completed cell. Each side has
three admitted primary observations. Bounds were recomputed directly from the
same cell's baseline median.

| Initialized size | Quantity | Baseline median | Candidate median | Unchanged bound | Result |
| --- | --- | --- | --- | --- | --- |
| 4 | Wall seconds | 0.1724750489993312 | 0.3440998709993437 | 0.2628413161490971 | Exceeded |
| 4 | Peak evaluator RSS KiB | 66604 | 125100 | 91447 | Exceeded |
| 64 | Wall seconds | 0.21975096299865982 | 2.74212385699866 | 0.32666380004819073 | Exceeded |
| 64 | Peak evaluator RSS KiB | 86604 | 491728 | 116447 | Exceeded |

The arithmetic is `0.1724750489993312 * 1.35 + 0.03 =
0.2628413161490971` seconds and `66604 * 1.25 + 8192 = 91447` KiB at size 4.
At size 64 it is `0.21975096299865982 * 1.35 + 0.03 =
0.32666380004819073` seconds and `86604 * 1.25 + 8192 = 116447` KiB.

Every attempted output passed the maintained observer's complete projection
contract. Every size-4 output also matched the retained raw size-4 bytes exactly.
Every attempted size-64 output matched across sources and modes, including
warmups and the sample subsequently excluded at environmental release.

| Size | Output bytes | Complete stdout SHA-256 |
| --- | --- | --- |
| 4 | 384 | `546aa0de311d8d1948fb5fdd5ef6950f8583bb594200350f7d0fb6755e4df8f0` |
| 64 | 3271 | `9d7f29a88907fd79da7c9f5d28125c4d5f6a47257d9c9240d218ccc9b688fba3` |

## Raw observations and stop

Wall seconds below are rounded to nine decimal places for reading. Exact values,
complete commands, output digests, exits and release fields are retained in
`observations.tsv`, `results-audit.json`, `ledger.json` and individual records.
Pair numbers identify the predeclared alternating pairs. They are not retries.

| Attempt | Size | Initialization | Side | Repetition | Wall seconds | Peak RSS KiB | Campaign admission |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 4 | Enabled | Baseline | Warmup | 0.296790656 | 66012 | Admitted |
| 2 | 4 | Enabled | Candidate | Warmup | 0.345838488 | 125140 | Admitted |
| 3 | 4 | Enabled | Baseline | Pair 0 | 0.172475049 | 66604 | Admitted |
| 4 | 4 | Enabled | Candidate | Pair 0 | 0.350108762 | 125116 | Admitted |
| 5 | 4 | Enabled | Candidate | Pair 1 | 0.344099871 | 125064 | Admitted |
| 6 | 4 | Enabled | Baseline | Pair 1 | 0.168852435 | 66740 | Admitted |
| 7 | 4 | Enabled | Baseline | Pair 2 | 0.176530994 | 66452 | Admitted |
| 8 | 4 | Enabled | Candidate | Pair 2 | 0.334028905 | 125100 | Admitted |
| 9 | 64 | Enabled | Baseline | Warmup | 0.227134060 | 86064 | Admitted |
| 10 | 64 | Enabled | Candidate | Warmup | 2.749320406 | 491284 | Admitted |
| 11 | 64 | Enabled | Baseline | Pair 0 | 0.219750963 | 86604 | Admitted |
| 12 | 64 | Enabled | Candidate | Pair 0 | 2.742123857 | 491940 | Admitted |
| 13 | 64 | Enabled | Candidate | Pair 1 | 2.698030206 | 491728 | Admitted |
| 14 | 64 | Enabled | Baseline | Pair 1 | 0.221707917 | 86608 | Admitted |
| 15 | 64 | Enabled | Baseline | Pair 2 | 0.218652161 | 86500 | Admitted |
| 16 | 64 | Enabled | Candidate | Pair 2 | 2.907214115 | 491700 | Admitted |
| 17 | 64 | Disabled | Baseline | Warmup | 0.214749502 | 86484 | Admitted |
| 18 | 64 | Disabled | Candidate | Warmup | 2.693640067 | 491536 | Admitted |
| 19 | 64 | Disabled | Baseline | Pair 0 | 0.216481737 | 86224 | Admitted |
| 20 | 64 | Disabled | Candidate | Pair 0 | 2.689492671 | 491664 | Admitted |
| 21 | 64 | Disabled | Candidate | Pair 1 | 2.768967873 | 491480 | Excluded at host release |

The runner acquired the shared Praxis lock `/tmp/praxis-1000/lexicon-gate` before
host admission. The inode was created through the existing lock protocol without
truncation and retained. Recorded host admission and release checks for attempts
1 through 20 reported no unreadable processes and no recognized foreign workload.
These are checkpoint observations, not continuous whole-host isolation.

Attempt 21's admission reported no foreign workload. Its evaluator and observer
both exited 0, complete output was valid, the evaluator was reaped, the observer
was reaped and its process group was absent. Its release snapshot then recorded
foreign PID `947128`, command name `nix`. The runner stopped there with exit 1 and
the recorded status `stopped; no retry; AssertionError('foreign workload;
retained hold with no retry')`. No signal, subsequent quiet polling or retry was
performed. The foreign process's identity or activity wasn't investigated further.

The observer's own `admitted` field is true for all 21 records. Campaign admission
is true only for the first 20 because host release precedes campaign admission.
Attempt 21's metrics remain raw cost evidence and do not enter a comparison.
Its missing `sensitivity-record.json` records that failed boundary; its observer
record, stdout, stderr, observer logs and failed release snapshot are all retained.
All 21 attempted evaluators, observers and observer groups have release evidence.
The lock was released in the runner's finalization path.

The last three scheduled launches, raw size-64 pair-1 baseline and pair-2
baseline/candidate, were never attempted. There is no raw size-64 median cell,
and partial pairs weren't promoted into one. No final successful batch-release
record is claimed after the stop.

## Costs and retained evidence

| Accounting quantity | Retained starting total | This invocation | Cumulative recorded total |
| --- | --- | --- | --- |
| Workloads | 165 | 21 | 186 |
| Evaluator seconds | 84.76011121302872 | 22.755990694986394 | 107.51610190801512 |
| Runner seconds | 127.14589780299139 | 37.05867250799929 | 164.20457031099068 |
| Separate version queries | 126 | 21 | 147 |

The 21 launches contain six warmups and fifteen primary attempts. Twenty samples
were campaign-admitted, including fourteen primary observations. The excluded
attempt still counts in workload, evaluator, runner and query costs. Every
attempt has a complete evaluator record; there are no unknown evaluator-launch
or query costs in this invocation and no failed workload prelaunches. This
doesn't assign costs to unmeasured setup or waiting. Functional accounting stays
separate. Runner elapsed includes its verification and observation work; nothing
was subtracted. The one invocation used fewer than 24 launches and 25 queries,
and no evaluator or runner timeout occurred. Unused capacity grants no retry.

All packet and result evidence is retained locally under
`nix-effects-diagnostic-worktree/.runtime/praxis-diagnostic-cost`.
These ignored runtime files aren't shipped in a repository clone.

| Record | Purpose |
| --- | --- |
| `readiness.json`, `identities.json` | Reviewed identities, exact schedule and commands, input inventories, control reuse and policies |
| `launch-invocation.json`, `launch-completion.json` | Actual invocation and observed exit 1 with complete runner output hashes |
| `toolchain.json`, `toolchain-command.json`, `environment.json`, `lsp-admission-actions.json` | Runtime resolution, settings, initial environmental hold and launch-time LSP inspection |
| `admission.json`, per-attempt `.admission.json` and `.release.json` | Host-visible checkpoint observations, including the foreign-workload stop |
| `lock-admission.json`, `lock-release.json` | Shared machine lock acquisition and release |
| `samples/<name>/record.json`, `stdout`, `stderr`, observer output logs | Complete raw capture and evaluator/observer lifecycle for every attempt |
| `samples/<name>/sensitivity-record.json` | Campaign admission for the first twenty samples only |
| `ledger.json`, `comparisons.json` | Stopped accounting and the two completed comparisons |
| `observations.tsv`, `results-audit.json` | Offline complete-output replay, sample disposition, independently recomputed arithmetic and custody verification |
| `results-manifest.json` | 194 sealed packet/result files with content hashes and permission modes; excludes interpreter cache, itself and later report verification |

The sealed results manifest SHA-256 is
`786fc1d8fa2ea55f6ff6dd1f8bcf86caf742a74a7d1b6b0e05c7e82bf75f2a3d`.
The manifest includes the unchanged reviewed packet, authority, stopped ledger,
complete sample evidence and offline result audit. It doesn't include this report.

The exact 22-control reuse map was rechecked against actual records, complete
stdout/stderr, rejection and release semantics. The maintained observer's output
validator was replayed offline, without launching controls or an evaluator. The
six older baseline/missing-source/timeout records retain evaluator release and
synchronous parent-ledger evidence; they don't have a separate historical
observer-group assertion. The newer sixteen candidate controls retain explicit
observer/group release and expected rejection assertions. The reuse map preserves
that distinction. Observer, dispatcher, fixture and evaluator bytes matched;
retained Python executable path and full version matched, without asserting an
unrecorded historical Python binary digest.

Preparation and post-stop checks verified both archived baseline inventories and
their locks, five protected manifests, 25 frozen-file identities, 5,167 prior
evidence hashes and all 23,957 entries in the retained preservation inventory.
Live/frozen candidate content, kinds and full permission modes still matched.
The original stopped packet and its verifier were read, preserved and never
executed. Its obsolete main-branch requirement wasn't edited. New verification
binds the preservation branch and diagnostic branch separately. Stale raw-bound
abort wording and earlier starting totals were corrected only in new records.

## Attribution and remaining acceptance

Initialized size 64 still fails. Under the declared interpretation, fixed public
empty-success report initialization is insufficient. Both initialized cells
failed, so the experiment doesn't support the proposed classification requiring
both initialized cells to pass while raw 64 fails. The interrupted raw cell
cannot supply that missing comparison.

Report-policy/handler setup in separately demanded instances, first-emission
initialization and workload-dependent validation, adaptation or re-emission
remain unresolved alternatives. Public pre-demand can't identify an
individual native allocation, prove unavoidable overhead, determine a production
correction owner or approve raw cost. Comparing this initialized size-4 campaign
with historical raw size 4 doesn't establish exact causal cost. No such
subtraction or attribution is made here.

The retained raw size-4 primary failure remains candidate wall median
0.34825753800032544 seconds against bound 0.26440254119959716 and peak RSS median
122628 KiB against bound 88317, with matching complete 384-byte outputs.
Selected-manifest passes at 4/16/64 remain limited to the exact frozen graph.
Raw diagnostic size 16 and all assembled primaries remain unlaunched; this
sensitivity's partial raw size 64 doesn't replace primary acceptance.

Foundation's Registry-64/resource-16 startup exceptions, fleet's five scoped
smaller wall exceptions and TOML's 100488744-byte standalone closure tradeoff
accept no Praxis or new assembled regression. Pure generated TOML rendering
remains delivered, with TOML Kit owning parsing and retained syntax. No dependency
correction, lock refresh, new cost exception or production priming follows from
this result.

Inherited platform and evidence constraints remain unchanged. Two-system pure
evaluation isn't native aarch64 execution. The x86-only consumer example,
unavailable aarch64 theme builder and two early combined-only worker-log records
remain disclosed limitations of this experiment. This phase
ran no new functional or platform gate and makes no additional support claim.

## Scope of evidence

This report records the stopped historical experiment and its admitted results. It did not
establish a correction, new platform support or performance acceptance. Later integration
and benchmark results do not turn its missing observations into measured passes.
