# Praxis architecture

```text
Nix declarations
  -> validation and reference traversal
  -> versioned JSON manifest
  -> argument binding and expanded plan
  -> ordered prompts and child processes
```

## Evaluation

`src/praxis.nix` assembles the compiler and packages its outputs. `schema.nix`,
`parameters.nix`, and `interaction.nix` validate the declaration language using
Axiom schemas and Krisis diagnostics. `fields.nix` shares primitive validators,
scalar normalization, and environment-key naming. `graph.nix` checks reachable
references, alias collisions, and sensitive environment namespaces.
`wrapper.nix` supplies a manifest path and command name to the shared runner.

Praxis is independent of Ownerships and Furnish. The optional roster adapters
translate external data into ordinary declarations; they are not core runtime
dependencies. Program is the composition layer for Lexicon's systems.

Selecting one command package validates only that command and its reachable
references. Unrelated declaration bodies remain lazy. The dispatcher and
all-command bundle validate the complete command set. Diagnostics and their
summaries remain available without constructing derivations.

Static defaults, choices, metadata, UI settings, and prompt declarations enter
the manifest. Environment-backed values are resolved by the runner. Sensitive
values never belong in the manifest; only their source descriptors do.

A manifest is immutable package data. Live script files are deliberately not
copied into it: execution resolves them from the effective working directory.
Changing a declaration requires rebuilding its package; changing a live script
does not.

## Planning

The runner binds each command invocation independently. Named and short
parameters are indexed, environment defaults are validated, and group rules
run before execution. Reference arguments use literal argv boundaries rather
than shell interpolation. A repeated reference produces a repeated invocation.

An expanded step retains its reference chain, parameter conditions,
environment conditions, prompt or executable action, locks, UI, timeout
budgets, and sensitive-source descriptors. Environment maps are shared until an
override requires a copy. Child-command overrides do not leak to siblings.

`plan` does not start processes, acquire locks, resolve sensitive bindings, or
ask questions. Environment conditions remain runtime checks because earlier
prompts can supply run-local environment values. All reachable references and
ordinary argument bindings are validated even when a condition will skip them.

`doctor` uses the same plan, then checks the current filesystem and executable
search path. It cannot predict files that an earlier step would generate.

## Execution

The packaged runtime targets `x86_64-linux` and `aarch64-linux`. Its terminal
handoff, subreaper, process-group, and pidfd support use Linux APIs; it falls
back to bounded polling when pidfds are unavailable.

`run.rs` owns locks, condition checks, prompt responses, runtime secret input,
and step order. `interaction.rs` polls terminal input so cancellation and
timeouts can interrupt a prompt. Hidden-input terminal settings are restored
on every exit path.

`process.rs` owns the child process group, foreground terminal handoff, signal
forwarding, timeout escalation, and reaping. Command budgets span their
expanded sequence; a step or nested command may impose an earlier deadline.
Locks are released only after process cleanup. A program that creates a new
session is outside this boundary.

UI settings follow the execution scope and CLI overrides. Human progress is
written at boundaries, not redrawn over child output. JSON execution keeps
stdout for newline-delimited events and sends ordinary child output to stderr.
Secret-bearing child output is suppressed. Notification helpers are bounded
processes with a restricted environment; notification failure does not replace
the command's result.

## Source map

| File | Responsibility |
| --- | --- |
| `model.rs` | Manifest and plan-facing types |
| `arguments.rs` | Parameter binding, choices, groups, literal substitutions |
| `plan.rs` | Root policy, scope inheritance, ordered expansion |
| `cli.rs`, `inspect.rs` | Dispatch, metadata, show, plan, doctor |
| `completion.rs` | Candidate selection and Fish/Bash/Zsh integration |
| `interaction.rs`, `ui.rs`, `notify.rs` | Prompt policy, presentation, notifications |
| `run.rs`, `process.rs` | Execution and operating-system resource ownership |

## Verification

From the Lexicon root:

```fish
nix run path:.#formatter.x86_64-linux
and nix build --no-link path:.#checks.x86_64-linux.praxis-pure path:.#checks.x86_64-linux.praxis-integration path:.#checks.x86_64-linux.praxis-runtime path:.#checks.x86_64-linux.praxis-runner
and nix flake check path:. -L
```

The pure suite covers normalization, diagnostics, and lazy boundaries. Runtime
checks cover literal argv/environment, references, roots, scripts, prompts,
choices, conditions, sensitive input, notifications, terminal restoration,
timeouts, descendants, locks, completions, and CLI snapshots. The runner
package also runs Rust unit tests and warning-denying Clippy.

The benchmark harness measures short executions, large expanded plans,
parameter-heavy binding, command listing/completion, and Nix normalization.
It warms each case once, reports every sample and the median, and cleans its
temporary manifests. Run it from the repository root with the freshly built
runner, not a path to an older store result:

```fish
set runner (nix build --no-link --print-out-paths path:.#checks.x86_64-linux.praxis-runner)
and nix develop path:. -c python3 tests/praxis/benchmark.py "$runner/bin/praxis" --repetitions 5 --nix-count 2000
```

Timings depend on the machine, caches, and workload. The harness is a local
measurement tool, not a cross-machine acceptance threshold or a comparison
against third-party crates. [Runtime dependencies](dependencies.md) records
those integration decisions separately.
