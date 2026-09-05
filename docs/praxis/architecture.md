# Praxis architecture

```
Nix declaration
  -> Axiom validation and Krisis diagnostics
  -> normalized JSON manifest, version 1
  -> one shared Rust runner
  -> child processes, sequentially
```

The per-command executables are thin launchers. They provide the immutable
manifest path and selected command to the same runner. The dispatcher uses a
manifest of all declarations. Neither does Nix evaluation at runtime.

`schema.nix` and its field/parameter helpers normalize the DSL. `graph.nix`
validates reachable references. `wrapper.nix` packages launchers; it does not
implement a second orchestration engine. `package.nix` builds the Rust crate
using a checked-in lockfile. The runner uses serde for JSON and libc for Linux
process groups, terminal ownership, signals, and advisory locks.

## Boundaries

- Selecting one package validates only that command and its reachable references.
  Diagnostics do not construct derivations or force unrelated payloads.
- The all-command manifest and bundle necessarily validate every declaration.
- Planning binds arguments and expands ordered references before the first step.
  It never deduplicates repeated calls, starts children, acquires locks, or asks
  for confirmation. Live scripts are resolved at execution, not planning.
- Each executable step gets a fresh process. Environment changes, shell
  functions, and `cd` inside one shell do not leak into later steps.
- Signals are forwarded to the active process group. Cancellation escalates to
  SIGKILL after two seconds; remaining group members are terminated and reaped
  before the runner releases locks. Programs deliberately escaping into another
  session are outside this contract. Praxis is not a service supervisor.
- Terminal output is boundary-based rather than redrawn over child output.
  Interactive children receive the foreground terminal and restore it on exit.
- Confirmation happens at the declared step, so earlier steps may already have
  effects. Failures preserve the child exit code and skip later steps.

The installed manifest includes declarations and environment overrides. Do not
put secrets in Nix declarations. Changing a declaration means rebuilding and
reinstalling its package; live scripts are intentionally different.

## Runtime type boundaries

Argument lists and parameter defaults now use Axiom runtime type descriptions
through Krisis `validateType`. The schema's parser fields return validated values
instead of repeating boolean checks and normalization. Dependent stages use
`validation.andThen`; independent checks still accumulate in their existing
category order. Runtime path parameters remain non-empty strings, not Nix paths.

Malformed argument alternatives retain each failed branch's reason and nested
path, so one bad argument may produce more than one `praxis/args-shape` diagnostic.
The established diagnostic codes remain. Structured paths are zero-based and
relative to the primary field label; older step/parameter subject labels retain
their existing one-based numbering. Unknown environment names are rejected before
the corresponding values are inspected.

`diagnosticSummaries.<command>` exposes total, severity counts, code counts, and
`hasErrors` for the selected command and its references. Like `diagnostics`, this
projection does not force sibling commands or builders. No manifest or runner
protocol changed. The older measurements below concern the preceding runner
optimization, not this runtime-type addition.

Program's spelling suggestions now share Krisis' bounded vocabulary matcher.
Furnish and Ownerships use the optimized Axiom schema, requirements, and phase
machinery without changes to file authority or ownership merge semantics.

## Why a Rust runner

Praxis needs process management and a consistent CLI, not an embedded evaluator.
Using the existing Nix or Lix executables keeps that boundary small. Native
Nix/Lix evaluator bindings would add a second compatibility surface without
helping the core task of running ordered commands.

There is no daemon, arbitrary-command cache, automatic retry, resume engine,
plugin host, remote scheduler, or parallel DAG. A reference is an ordered call,
not a dependency that gets silently deduplicated.

## Evaluation and runtime costs

Axiom owns the closed schemas and accumulating validation results. Krisis owns
diagnostic construction and rendering. Praxis keeps command-specific rules at
that boundary; no extra functional framework is needed for the command graph.

The Nix layer shares each command's normalized manifest value and reference
list across selections. Unrelated commands remain lazy. Parameter references
use an attribute-name index, environment-name collisions use `builtins.groupBy`,
and positional ordering uses one strict fold rather than repeatedly scanning
prefixes. Graph validation still checks cycles; reference execution still
preserves every ordered call.

The runner borrows argument values while binding them, indexes named parameters,
and copies strings when constructing the owned plan. Steps without environment
overrides share one immutable map; overrides copy that map before changing it.
Plan JSON is written through a buffered serializer rather than materialized as
another complete string.

On Linux with `pidfd_open`, short children wake the wait loop on exit instead
of paying a fixed 20 ms sleep. The runner's child handle still owns reaping.
Unsupported kernels and sandboxes returning `ENOSYS` or `EPERM` retain the
bounded polling path; other notification errors go through process cleanup.
Cancellation, escalation, terminal restoration, and lock lifetimes are unchanged.

The [benchmark](../../tests/praxis/benchmark.py) measures short-step execution,
large environment plans, argument binding, and Nix parameter validation. It
prints every sample and the median after one warm-up. It needs Python 3 and
Nix or Lix on PATH; it isn't a timing assertion in the gate.

```fish
nix build --no-link path:.#checks.x86_64-linux.praxis-runner
and python3 tests/praxis/benchmark.py (nix eval --raw path:.#checks.x86_64-linux.praxis-runner.outPath)/bin/praxis
```

The runner argument selects the Rust binary. The Nix case always evaluates
the repository containing the benchmark script, so comparing Nix changes
requires running it from each source revision.

On 2026-09-05, the same x86_64 Linux machine running kernel `7.2.3-cachyos`
produced these median wall times. These are synthetic warm-run measurements,
not estimates for a project's builds or tests. The [raw samples](benchmark-results.json)
record all five runs and the two runner paths.

| Workload | Before, seconds | After, seconds |
| --- | --- | --- |
| Run 100 short steps | 2.039346 | 0.126888 |
| Plan 3,000 steps with 256 environment values | 0.175785 | 0.059051 |
| Plan with 2,000 named parameters | 0.007853 | 0.003240 |
| Nix validation of 2,000 parameters and references | 0.526718 | 0.357124 |

The language references are Nix 2.25's [built-ins](https://nix.dev/manual/nix/2.25/language/builtins),
[operators](https://nix.dev/manual/nix/2.25/language/operators), and
[syntax](https://nix.dev/manual/nix/2.25/language/syntax). Shared Axiom and Krisis
source now uses `|>`. Nix 2.25 needs `pipe-operators` enabled; the tested Lix
version accepts pipes without a flag. These operators change application
syntax, not traversal cost. See [local development](../local-development.md)
for feature configuration and coordinated dependency checks.

## Migration and unreleased changes

The Rust runner starts at package version `0.1.0` with manifest version `1`.
The former always-root-bound shell wrapper has been replaced. Existing
`steps`, `run`, `script`, `args`, `env`, and `runtimeInputs` declarations remain.
The default cwd policy is now caller-relative and `requireRoot = false`.
To retain the old root guard, set both `root = ./.;` and `requireRoot = true;`.
That guard checks a regular, nonsymlink `flake.nix` against the build-time content,
rejects Nix-store directories, and runs once before execution. It is an
accidental-wrong-checkout guard, not cryptographic project identity.

New syntax includes string/list command shorthand, `exec`, command references,
typed parameters, explicit forwarding, runtime cwd/discovery, confirmations,
named locks, a dispatcher, plan output, completions, and terminal-aware progress.
The all-command bundle and runner are separate from the existing per-command
`packages` and `apps` so consumers can keep their current output wiring.

## Development gates

From the Lexicon root:

```fish
nix run path:.#formatter.x86_64-linux
nix build --no-link path:.#checks.x86_64-linux.praxis-pure path:.#checks.x86_64-linux.praxis-integration path:.#checks.x86_64-linux.praxis-runtime path:.#checks.x86_64-linux.praxis-runner
nix flake check path:. -L
```

The pure suite covers normalization, invalid declarations, and lazy boundaries.
Integration checks cover live scripts, literal argv/env, ordering, exact failure
codes, optional root behavior, planning, references, parameter binding,
confirmations, locks, cancellation/descendant cleanup, and a pseudo-terminal.
The runner package also runs Rust unit tests and warning-denying Clippy.
