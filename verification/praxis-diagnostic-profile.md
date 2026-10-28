# Praxis diagnostic profile

The complete `praxis-diagnostics` workload completed all eighteen scheduled
launches on 2026-10-25. At size 64 the frozen candidate applied 16,520,789 Nix
functions where the immediate baseline applied 346,297. 16,100,905 of the
candidate's applications, and 2,811 of its 3,079 self samples, fall in the
predeclared category for vendored nix-effects internals. Most of those samples
are in the type-theory kernel under `vendor/nix-effects/src/tc/`. Sampled stacks
enter the kernel almost entirely through Krisis `expect` validating diagnostic
fields. Exact definition counts show why that validation runs so often. In
aggregate the run recorded 576 emissions for its 128 final diagnostics. Each
recording path builds a diagnostic three times, and every build validates its
severity and code envelope.

The cost is a product of factors whose source boundaries have different owners.
Kernel work per validation and validations per recorded emission are in Krisis.
Recorded emissions per final diagnostic come from the candidate's Praxis
adaptation. This profile doesn't choose a correction, assign the total cost, or
establish an accepted or unavoidable cost. The earlier [cost report](praxis-diagnostic-cost.md) measured the regression this profile locates.
These are historical measurements, not a claim about later dependency revisions.

## Question and method

The question was where the unchanged complete workload does additional work,
separated into checker construction, checker application, emission and
collection, Praxis adaptation, and graph and result transport. A correction owner
is named only where source evidence establishes one.

Each source and size ran once in each of three evaluator modes. Ordinary capture
has no instrumentation. Flamegraph sampling uses the evaluator's own profiler at
1000 Hz. Counting sets `NIX_COUNT_CALLS` and `NIX_SHOW_STATS` with a per-launch
statistics file. Sampling and counting never share a process. Six controls on the
candidate at size 4 ran first, one complete and one malformed per mode. Twelve
observations followed, covering baseline and candidate at sizes 4 and 64 in each
mode. Every launch demanded the complete projection with report initialization
disabled. There were no warmups, retries or extra launches.

The historical `components/observe.py`, `components/profile-contracts.py` and components guide
owned this campaign's capture, record validity and source mapping. Their exact executed and
corrected identities are retained below. The maintained benchmark now owns capture and analysis
under [bench](../bench/reference.md); the historical campaign's records and claims are unchanged.
Region tables were
predeclared before any observation. Each table partitions one file by exact
anchor lines and is resolved separately against the bytes of each side's root. A
mapped position whose bytes differ from the resolved table stays unclassified.
The tables cover Krisis `validation.nix` (one table per revision, because the
per-value lambda moved), Krisis `report.nix`, and the lexicon `effects.nix` and
`src/praxis/type-checks.nix`. Whole-file and directory rules cover the rest.

## Measurement identities

The measurement basis was `a9b303293eb17c3d6f669b35acb0896eccc239e6`. The frozen
candidate and immediate baseline are identified separately below.

| Input | Identity |
| --- | --- |
| Frozen candidate | `praxis-production-integration/final-candidate/source`, 356-file manifest SHA-256 `4bd1bd91e8ae08bb07120b8039d8bebb755020568567a06c9579204c6d03bbe1` |
| Candidate lock SHA-256 | `5677cbb7fb467a68922190375bbcb9b48e8850a87d6d1930a029de5926b4107e` |
| Immediate baseline | `praxis-final/immediate`, revision `11204c6592fdf4693075d08f44115751c3cc7881` |
| Baseline lock SHA-256 | `0becfd8dc0e64bd9269e44198379e6affb1c2610f155e0d5076b35838b02d2e1` |
| Krisis | Candidate `c48e40834fe90299096d2988433b17f650c30c8a`, baseline `c8c71c0a81012ebfc2d82a5c65da5ed8b8c195f0`; between them only `src/validation.nix` differs |
| Evaluator | Nix 2.34.8, binary SHA-256 `f7eaf4e186b1a1baa9ac5f5c21dfc3226436e703e7e92b830ca62758ded9e84b`, source read at `f3f1c3c5b8ad91850e0f7c590cf177f7ab022024` |
| Frozen dispatcher and fixture SHA-256 | `80373f43e545962798cd49553f69284e5da64c917f04c67ecc9495202cfc0244`, `3fa7155e9a8a53731f19fb1120665c44ceab5d9c19931d442aa91c41e407a98f` |
| Executed readiness and `identities.json` SHA-256 | `2a54a119e2210d46ab7664bbe2ce4ba390a3d896dacfb2c85e454bf3272d7a6d`, `f223d860b64dbf011cca99557765846726a9fda15cc20be504cc13e2be1588df` |

The first capture attempt, against readiness
`cefbdfe69bbba0ce4541b751022ad3652aba7770bb3710fa801a340892a1aa4c`, stopped on a foreign
`cargo` process before any workload. It added 1.1077095000073314 runner seconds and no
workloads or queries. The completed attempt used the same eighteen-item schedule after
run-scoped path substitution and acquired the shared gate lock without contention. Host
admission, per-attempt checks and final release found no foreign process.

### Tooling identities

The campaign executed `observe.py`
`435b2a24f2ab53d2ea2677bdb4eb204948429e75f9fd541d9f984162675d2143` and
`profile-contracts.py`
`d94f34ff6237251034f2d02c93af205802d7f569450fb8f4c2fe55f9e5c7a7ec`, as bound in
the executed readiness. The passing gate below verified those bytes too. Review
then corrected `profile-contracts.py`:

- It now enforces the 2.34.8 writer's integer and position grammar.
- It maps a zero statistics column at line level.
- It reports line 0 as unresolved.
- It indexes each origin once.

The README changed to match. `observe.py` is unchanged. A third full gate passed
on the corrected tool bytes, as described below. Replaying all twelve retained instrumentation records
through it gives byte-identical summaries. Every analyzed map and the
classification summary are byte-identical, so the results below hold under
either version.

## Controls

All six controls qualified. The three complete controls were admitted with the
exact retained size-4 output. The three malformed controls exited 1 with no output,
no validation error and the exact reference terminal line. They count as
qualified expected rejections, not successful samples. Both instrumented malformed
controls proved capture with a present, valid record: a 193,228-byte profile and
363,442 bytes of statistics. The evaluator writes both on its error path. The
complete controls' records are kept for capture qualification only and don't
enter the comparisons below.

## Observations

Every observation was admitted with the exact retained output for its size.
Each cell is a single launch, so the wall and RSS values aren't medians. The
instrumented values are recorded costs, not acceptance figures or overhead
estimates.

| Side | Size | Ordinary wall s | Ordinary peak RSS KiB | Applications | Primop calls | Profile samples | Statistics CPU s |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Baseline | 4 | 0.174 | 64,216 | 54,457 | 27,859 | 66 | 0.109 |
| Candidate | 4 | 0.346 | 122,696 | 1,099,109 | 295,435 | 265 | 0.289 |
| Baseline | 64 | 0.210 | 86,372 | 346,297 | 220,099 | 123 | 0.156 |
| Candidate | 64 | 2.803 | 491,564 | 16,520,789 | 4,360,075 | 3,079 | 2.872 |

There are 2N final diagnostics, 8 at size 4 and 128 at size 64. Between those two
observed sizes the candidate's applications rose by 15,421,680 for 120 more
diagnostics, about 128,500 applications per added diagnostic. Two sizes don't
establish a general growth law, and size 16 wasn't observed. At size 64 the
candidate allocated 17,655,888 values, against 503,766 for the baseline, and its
statistics report 866,892,096 total GC bytes, against 23,759,440.

### Categories

Counts take the category of each function's definition. Samples take the
category of their leaf frame. The inclusive view is reported separately, and no
leaf is assigned to an ancestor. These are size-64 values.

| Category | Baseline applications | Candidate applications | Baseline self samples | Candidate self samples |
| --- | --- | --- | --- | --- |
| interpreter (vendored nix-effects outside `types/` and `effects/typecheck.nix`) | 16,364 | 16,100,905 | 9 | 2,811 |
| axiom | 230,574 | 170,492 | 47 | 44 |
| unclassified | 50,869 | 87,179 | 51 | 79 |
| praxis-other | 40,139 | 42,270 | 11 | 13 |
| emission | 28 | 50,318 | 0 | 24 |
| application | 19 | 37,957 | 2 | 67 |
| transport | 24 | 19,124 | 0 | 10 |
| mixed | 3 | 6,692 | 0 | 5 |
| adaptation | 6,667 | 4,361 | 0 | 25 |
| construction | 5 | 782 | 0 | 1 |
| other-lexicon and fixture | 1,605 | 709 | 3 | 0 |

`interpreter` is the predeclared name for every vendored nix-effects path without
a narrower rule. It isn't reassigned here. The top counted definitions and the
2,878 vendored leaf samples show it's mostly the type-theory kernel, not effect
handling. By sub-path the samples split as `tc/eval` 1,073, `tc/hoas` 627,
`tc/conv.nix` 430, `tc/check` 286, `trampoline.nix` 182, `tc/value.nix` 82,
`types/foundation.nix` 51 and `tc/generic` 44. The most-applied definitions are
`forceVal` (708,076), `evalHybridAt`, `mkValueF`, `envFromList` and the
`machine.nix` evaluator.

Categories record where code is defined or sampled, not what it demands. The
small `construction` count doesn't bound construction cost. Types or checkers
built while emitting or checking run in kernel or Krisis definitions and are
counted there.

Unclassified positions are mostly nixpkgs `lib` and `modules`, flake input
`flake.nix` and `lib.nix` files, and `«flakes-internal»/call-flake.nix`. None of
those is a declared root, so they stay unbound.

### Where the kernel is entered

Sampled stacks give context, not attribution. The derivation is reproducible by
`context.py` over the retained size-64 candidate map. Its rule nests, so each
table partitions the one above it.

1. Select stacks whose leaf frame maps to Krisis `vendor/nix-effects/src/`.
2. Their entry is the first frame above the leaf that isn't mapped into
   `vendor/nix-effects/`. Unpositioned, unmapped and other-root frames count as
   outside.
3. For entries at Krisis `src/types.nix:116`, `expect`'s `type.check value`, the
   caller is the next frame above that isn't in `src/types.nix`.
4. For callers in `src/diagnostics.nix`, the origin is the next frame above that
   isn't in `src/diagnostics.nix`.

Of 3,079 samples, 2,878 have a vendored leaf. 2,792 of those enter at
`types.nix:116`. The rest enter at `validation.nix:127` (52), `spine.nix:7` (9),
`report.nix:55` (5), `validation.nix:146` (3), `types.nix:6` (2) and other
frames (15).

| Caller of the 2,792 | Source | Samples |
| --- | --- | --- |
| `diagnostics.nix:11` | `qualify` checks the namespace against `T.Maybe types.nonempty` | 1,514 |
| `diagnostics.nix:44` | `make` checks the severity and code envelope against `types.envelope` | 1,231 |
| `diagnostics.nix:12` | `qualify` checks the code against `types.nonempty` | 44 |
| `diagnostics.nix:87` | `defaults` checks its namespace | 3 |

| Origin of the 1,231 envelope checks | Source | Samples |
| --- | --- | --- |
| `report.nix:34` | `operation` builds the raw diagnostic | 396 |
| `report.nix:87` | the `record` handler rebuilds the received diagnostic | 392 |
| `report.nix:38` | the `applyDefaults` call in `operation`'s send, which rebuilds it | 359 |
| `validation.nix:108` | the `typeCheck` handler builds the failure diagnostic | 81 |
| `validation.nix:85` | a checker's diagnostic template | 3 |

The 1,558 `qualify` samples have a different origin. Their next frame above is
inside the kernel, at `tc/generic/check.nix:570`. A separate view overlaps the
tables above, so it isn't added to them. Skipping kernel, `diagnostics.nix` and
`types.nix` frames, all 1,558 are enclosed by `report.nix:38`, and every one has
the `diagnostics.nix:44` envelope check above it. That matches the source.
`applyDefaults` passes `code = qualify …` into `make`, and checking the envelope
forces that field. The `applyDefaults` path therefore encloses 359 + 1,558 =
1,917 of the 2,792 samples.

Size 4 shows the same structure. 195 of 209 vendored leaf samples enter at
`types.nix:116`, with callers `:11` 99, `:44` 94 and `:87` 2. These positions
carry `call-site-or-lambda-definition` provenance, because Nix 2.34.8 prints a
lambda's definition when its call site doesn't resolve. They are observed frame
positions, not proven call sites.

### Why it runs so often

Counts are exact applications by definition position. Every curried argument is
its own lambda with its own count, so the table names the exact position used
for each logical call.

| Definition position | Meaning | Size 4 | Size 64 |
| --- | --- | --- | --- |
| Krisis `validation.nix:100:17` | `typeCheck` handler, its argument | 8 | 128 |
| candidate `effects.nix:36:17` | `emitAll` fold step, `diagnostic` argument | 28 | 448 |
| Krisis `report.nix:85:5` | `record` handler, final `{ param, state }` argument | 36 | 576 |
| Krisis `report.nix:32:11` | `operation`, `raw` argument | 36 | 576 |
| Krisis `diagnostics.nix:112:13` | `applyDefaults`, `args` argument | 36 | 576 |
| Krisis `diagnostics.nix:10:16` | `qualify`, `code` argument | 36 | 576 |
| Krisis `diagnostics.nix:32:5` | `make`, its argument | 121 | 1,861 |
| Krisis `types.nix:115:17` | `expect`, `value` argument | 195 | 3,015 |
| Krisis `report.nix:130:5` | `finish`, its argument | 54 | 774 |
| candidate `type-checks.nix:71:29` | `check`, `value` argument | 24 | 384 |
| candidate `effects.nix:34:5` | `emitAll`, its argument | 50 | 710 |
| candidate `effects.nix:47:5` | `fromAxiom`, its argument | 41 | 581 |
| candidate `effects.nix:78:38` | continuation after `emitAll` in non-empty `fromDiagnostics` | 9 | 129 |
| candidate `effects.nix:125:14` | `resultOf`, its argument | 27 | 387 |

The baseline applies none of the Krisis definitions above except `finish`, 3
times at both sizes. Its `effects.nix` is byte-identical and applies `emitAll`
and `fromAxiom` 3 times each.

Recorded emissions are 576 at size 64, against 128 final diagnostics: 4.5 per
diagnostic in aggregate, not a per-diagnostic multiplicity. Size 4 gives 36
against 8. The emissions come from 128 native `typeCheck` failures and 448
lexicon `emitAll` steps. `emitAll` was entered 710 times, consistent with 129
non-empty `fromDiagnostics` continuations plus 581 `fromAxiom` applications. The
counts don't split the 448 steps by caller.

The source gives the shape. The candidate's `check` interprets each Krisis
checker in its own report (`type-checks.nix:73`), adapts the blame, and re-emits
through `fromDiagnostics` (`type-checks.nix:100`). The public entry points turn
reports back into Axiom results with `resultOf`, and callers re-emit them through
`fromAxiom`. In Krisis, every emission passes through three builds:

- `operation` builds the raw diagnostic (`report.nix:34`).
- It sends a lazy `applyDefaults` call (`report.nix:38`), which calls `qualify` and builds again (`diagnostics.nix:111`-`119`).
- The `record` handler builds once more from the received value (`report.nix:87`).

Those 3 × 576 builds, plus the 128 `typeCheck` handlers (`validation.nix:108`)
and 5 checker templates, are exactly the 1,861 `make` applications.

`make` forces its envelope check with `builtins.seq` (`diagnostics.nix:44`-`50`).
Its message, related, notes, help and location checks are lazy fields. `qualify`
forces its namespace and code checks. The demanded envelope and `qualify` checks
account for 1,861 + 2 × 576 = 3,013 of the 3,015 `expect` applications. At most
2 remain for every lazily guarded field and for `defaults`. `qualify` applies
`T.Maybe` to `types.nonempty` inside its body on every call. That application
doesn't show whether it yields a distinct type instance or repeated kernel work,
and these records can't separate type construction from checking within the
sampled kernel time.

## Ownership

Three factors multiply, and each stops at a demonstrated source boundary.

1. Kernel work per validation sits behind Krisis `src/types.nix` `expect`, called
   from `src/diagnostics.nix`. Over 3,015 `expect` applications, the 16,100,905
   vendored applications average about 5,340 each. That's a ratio of totals, not
   a per-call measurement.
2. Validations per recorded emission are set by Krisis `src/report.nix`
   `operation` and `record` and `src/diagnostics.nix` `applyDefaults` and `qualify`.
3. Recorded emissions per final diagnostic, 4.5 in aggregate, are set by the
   candidate's nested report in `src/praxis/type-checks.nix` `check` and the
   `src/effects.nix` round trips.

These Krisis files are identical in both pinned revisions. The baseline doesn't
exercise the validation path. Its application counts are dominated by Axiom
definitions (230,574).

Source ownership of each boundary is demonstrated. The choice of correction, and
the attribution of total cost between the factors, stay unresolved. Changing any
one factor changes the product, and this profile doesn't establish which
correction, or which combination, is required. Graph and Praxis transport
outside `type-checks.nix` doesn't stand out. praxis-other is 42,270 applications
against the baseline's 40,139.

## Limitations

- Sampling happens only on function entry. Primop and thunk time is credited to
  the next stack entered. Samples locate execution; they don't measure exact
  cost or time of first emission.
- Lambda and functor frame positions may be definitions rather than call sites.
  Only positioned primop frames are proven call sites.
- Counts are applications per definition position, one per applied argument.
  They aren't closure instances. Attribute-selection counts aren't available in
  2.34.8.
- Each cell has one launch. There's no repetition, median or noise estimate.
  Instrumented wall time and RSS include the profiler or a final full collection
  and the call maps. No figure gives per-component RSS.
- nixpkgs and flake-plumbing frames have no declared root and stay unclassified.
- The evaluator limit is enforced by `SIGKILL` in every mode. A timed-out ordinary
  capture now records exit `-9` where it used to record `SIGTERM`. Historical
  real `SIGTERM` timeout controls don't qualify the changed path, which is
  qualified offline against the actual observer with a fake evaluator only. No
  launch in this run timed out.

## Gates

The first full gate ran from the profile worktree and failed after 51.048 s with
exit 1. Formatting changed none of 276 files. The flake check then failed.
`treefmt-check` logged `fatal: not a git repository` for the worktree's gitdir.
The cause is verified from source and the store snapshot. Nix 2.34.8's `path:`
fetcher accepts every path (`path.cc:160`, `archive.cc:40`), so the snapshot
carried the linked worktree's `.git` pointer file. It also carried the ignored
`.runtime/` scratch, 113 MiB. The check copies that snapshot and runs `git init`,
which follows the pointer to a host path the sandbox lacks.

The same gate reported `praxis-installed-consumer` failed with an empty message,
and no build log exists for it. Its derivation waited on `praxis.drv`, which was
still building. Nix 2.34.8 clears the remaining goals after a failure when
keep-going is off. Flake check also stops at the first reported result, which
explains why only that line printed. The build ran through the system daemon,
Lix 2.95.4, whose source isn't local, so this cancellation explanation isn't
independently established.

The second full gate ran once from an independent local clone at
`nix-effects-diagnostic-profile-worktree/.runtime/praxis-diagnostic-profile/gate-clone`.
The clone was made with `--no-local --no-checkout`, has a real `.git` directory
and no alternates, and was checked out detached at the published basis. The four
reviewed files were copied with their modes. Its 359 admitted files equal the
basis tree plus those four, in bytes, kinds and executable bits. They equaled
the profile worktree's reviewed files at that time, the status was exactly the
four paths, and the lock and
`flake.nix` matched the basis.

The gate passed with exit 0 in 309.824 s. Formatting changed none of 276 files,
all ten flake checks passed, and `praxis-installed-consumer` built and completed.
That derivation differs from the first gate's, because the snapshot differs, so
the earlier one never built. The check omitted `aarch64-linux`. Afterwards the
clone's manifest was unchanged, the lock had no holder, and recorded source identities were intact.

That gate verified the executed tool bytes. The third full gate verified the
corrected ones. It ran once from a second independent clone,
`nix-effects-diagnostic-profile-worktree/.runtime/praxis-diagnostic-profile/gate-clone-2`,
made the same way. It held the corrected `profile-contracts.py`
(`3fea7360015544ba474b48d73c5dee78c5eabcf170679e73077406c2163f4f55`), the README
(`8cf2f10e288bb77e2157456057f3e905868cc9a1ffce7ec6d8b51fdfce248037`), the unchanged
`observe.py` and the report as it stood before this paragraph
(`3b85ee3a9232e1a0e3b7bf503af35e7d908062aeccd05d4039ce2fa368050f69`). Its 359
admitted files equaled the basis plus those four and the profile worktree, and
the lock and `flake.nix` matched.

The gate passed with exit 0 in 444.323 s. Formatting changed none of 276 files,
all ten flake checks passed, and `praxis-installed-consumer` built. The check
omitted `aarch64-linux`. The clone's manifest was unchanged afterwards. The lock
had no holder, and recorded source identities were intact. A foreign
`nix flake check` from another project started during the gate's last 306 s. It
didn't hold the shared lock and wasn't signalled. This gate isn't a timing
measurement, so its duration isn't comparable with the second gate's.

This report's closing edits, recording the third gate, came after it. They change
no tool bytes and were checked offline as documentation.

## Inherited acceptance gaps

This profile doesn't change migration acceptance.

- The raw diagnostic size-4 primary failure stands: candidate wall median
  0.34825753800032544 s against bound 0.26440254119959716, and peak RSS median
  122628 KiB against bound 88317, with matching complete outputs. No inherited
  exception accepts it.
- Raw diagnostic size 16, a complete raw size-64 primary comparison and every
  assembled primary remain absent. The partial raw 64 from the earlier
  sensitivity doesn't replace primary acceptance.
- Selected-manifest passes at 4, 16 and 64 remain limited to the exact frozen graph.
- Foundation's Registry-64 and resource-16 startup exceptions, fleet's five
  scoped smaller wall exceptions and TOML's 100488744-byte standalone closure
  tradeoff accept no Praxis or new assembled regression. Historical exceptions
  don't cover an assembled miss.
- Platform and history constraints stay as published:
  - Native operational evidence is x86_64-linux, and two-system pure evaluation
    isn't native aarch64 execution.
  - The x86-only consumer example and the unavailable aarch64 theme builder
    remain.
  - Two early theme-worker records keep combined output only.
  - Lexicon evidence uses Nix 2.34.8, and nothing here claims Lix or Nix 2.25
    support or raises a consumer minimum.

## Costs and retained evidence

| Accounting quantity | Starting total | This invocation | Cumulative recorded total |
| --- | --- | --- | --- |
| Workloads | 186 | 18 | 204 |
| Evaluator seconds | 107.51610190801512 | 13.292744102014694 | 120.80884601002981 |
| Runner seconds | 165.312279810998 | 20.14690248000261 | 185.45918229100062 |
| Separate version queries | 147 | 18 | 165 |

The starting runner total already includes the stopped first invocation. Every
attempt has a complete evaluator record, so there are no unknown costs. The two
campaign development-shell invocations are kept outside these totals with their
inclusive wall times. The first ran 5.111972898 s and exited 1. The second ran
24.561125507 s and exited 0. Nothing was subtracted to estimate setup.

Functional execution is accounted separately: the first gate (51.048 s, exit 1),
the log retrieval shell (about 4.42 s, exit 0, with two `nix log` queries exiting
0 and 1), the second gate (309.824 s, exit 0) and the third (444.323 s, exit 0).

Evidence is kept locally under
`nix-effects-diagnostic-profile-worktree/.runtime/praxis-diagnostic-profile`.
These ignored runtime files aren't shipped in a repository clone.

| Record | Purpose |
| --- | --- |
| `attempt-2/packet/` | Executed readiness, identities, roots and resolved region tables |
| `attempt-2/ledger.json` (`6bab3265a0a4d1c4584e00ba35e5fbb8c3e9bbe09574faaec2bff30c007b67d0`) | Every attempt, outcome, release fact and cost |
| `attempt-2/samples/<name>/` | Output, stderr, `record.json`, `profile.folded` or `stats.json`, and the runner's sample record |
| `attempt-2/host/`, `lock-*.json`, `environment.json`, `devshell-*` | Admission and release scans, lock records, launch environment and shell outcome |
| `attempt-2/analysis/analysis-1/` (`summary.json` `a0ae5ca6ef07836477f91a30223e89adb95f877c78a73122056d787928c73e9a`) | Mapped frames and functions per instrumented record, with controls and observations kept apart |
| `corrective-1/` | Context derivation (`context-candidate-64.json` `20718c7d87d523d00c24dfef362d47d2a2f4dc5085bdbb1dde73c1a6c019a701`), definition positions (`definitions.json` `e45897744bfdcaee008532250f0b3f5ec9ffc1a7e00610e6f597506e5da7d922`), corrected-tool replay and qualification |
| `gate-1/` (`gate.stderr` `5aa3f2df3eb8852e39fb561f4659487249b439eb37586286ec13ec4452cec8f0`, `diagnosis/diagnosis.json` `88551a104529b24034a88825dda1dbff0f18aa20013a2a249f55e98e9336fd49`) | Failed gate, logs and diagnosis |
| `gate-2/` (`gate.stderr` `d9b0449e2263c3a47a1e10e6dd29cd8d87897035869d9f64d3aa778b7d223418`, `identity-proof.json` `56567b71155b06b1fc88e512b72fd146ff63f758045590034ecf72bc8215a18c`) | Clone creation, identity proof, passing gate and post-gate verification |
| `gate-3/` (`gate.stderr` `3e5a03f739cf6c8799f9527ff318e0928e7f1e72da889f01310faf5068aa15e9`, `identity-proof.json` `2ed7823585a661b42646c421ef3f3c880356ba0fc449700e665f550a59fc61fc`) | Corrected-tool clone creation, identity proof, passing gate and post-gate verification |
| `ledger.json`, `host/`, `packet-3/` and siblings at the top level | The stopped first invocation |
| `offline/`, `attempt-2/offline/`, `superseded/` | Offline qualification, runner, compatibility and classification checks, and superseded attempts kept as evidence |

## Scope of evidence

The campaign did not change production behavior or establish an accepted cost exception.
Its measurement identities and attribution limits remain part of this record. Historical
worktree custody, approval routing and proposed follow-up work are not technical results.
