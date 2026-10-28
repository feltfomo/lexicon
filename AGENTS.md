# Lexicon changes

Lexicon is a collection of quality-of-life features for the Nix language. Treat
its implementation as a functional library with distinct subsystem owners.
Preserve consumer declarations, public factories and extension contracts when
changing internals. Read the relevant source, callers and tests before editing.

The [philosophy](docs/philosophy.md) holds the laws, and
[functional design](docs/explanation/functional-design.md) explains their vocabulary.
Work toward the target layout follows the [restructure effort](docs/efforts/restructure.md).

Read [declaration syntax](src/lexicon/syntax.md) and the
[definition contract](src/lexicon/definitions.md) before extending the DSL.
Built-ins and external subsystems use one registered compiler. New annotations
belong to the configured Ownerships vocabulary. Native module bodies stay opaque.

## Functional design

Start with domain values, their invariants and the operations that consume them.
Use products for values needed together, tagged sums for alternatives, and
refinements for constraints. Give each invariant one owner. Keep input, result
and failure contracts explicit. Use the simplest representation that fits the
domain; dependent types and proofs need a concrete obligation.

Build transformations from small named functions with explicit inputs. Keep
subsystem algorithms separate from dependency assembly and interpretation.
Attribute sets can represent records, indexes or dispatch tables; choose their
shape for that role. Native configuration belongs at the module boundary.
Avoid a growing configuration record whose flags select unrelated behaviors.

Prefer dispatch by a validated tag or registered name when branches implement
the same operation for different variants. Keep each case with its domain owner.
Use maps, folds and composition when they express the transformation directly.
Keep `if` for actual decisions, guards and short-circuiting. Replace an expanding
`if`/`else if` chain when it is encoding a domain vocabulary; don't replace a
clear conditional with a dispatch table merely to remove branching. Validate
unknown variants before lookup and preserve which branch values remain lazy.

Separate pure domain functions, effectful computations and handlers. Use new
Krisis for diagnostics and prefer nix-effects where it supplies the required
types or composition. Share one corrected effect instance through one dependency
owner. Read the pinned public API before using it; don't reach through private
or experimental namespaces. Use `|>` for readable pure data flow and `fx.bind`
or `fx.map` for computations. A pipe applies a function; it doesn't bind effects.

Keep Axiom's `src` helpers where they own a capability still needed, including
compatible extension field schemas and collision-validating registries. Don't
import Axiom's `language` implementation. Don't rebuild a schema framework or
validate the same payload twice to use a different library. Compatibility
adaptation belongs at one boundary. Remove superseded internal paths as their
owners migrate.

## Evaluation and cost

Laziness is part of the contract. State which fields an operation may force.
Keep inactive payloads, native module bodies and unrelated output branches
opaque. Select context and output before invoking their callbacks. Preserve
shared static preparation and original authored origins through filtering.
Don't serialize or deeply force an entire plan to pass it between pure stages.

Protect arbitrary values across effect state and result boundaries using the
qualified dependency's thunk carriers. Test the complete transport path with
throwing values. Independent checks should accumulate errors; dependent work
runs only after valid input exists. A collecting handler's resumed value isn't
proof of success. Preserve callback exceptions at the expression actually forced;
don't use catch-all conversion to hide evaluation failures.

Choose algorithms and data layout before clever syntax. Reuse prepared indexes
and context-independent work where useful. Avoid repeated scans, growing list
or string append, and deferred closure chains in hot paths without a reason.
Build output fragments and join them once where practical. Account for index
allocation on small inputs. Measure actual components before claiming a speedup.
Preserve ordering and laziness when changing representations. Reassociation
requires the relevant algebraic law; custom merge callbacks needn't be associative.

Keep evaluation pure. Prefer pure Nix for compilation and rendering. Live
filesystem operations, locking and process execution belong to runtime owners.
Don't introduce import-from-derivation or mutable filesystem reads to move work
into evaluation. A pure renderer doesn't establish parser or publication parity.

Keep Lexicon pure Nix. Compilation, validation, rendering and docs generation are
Nix, with no helper in another language. A non-Nix component is allowed only for
work that runs outside evaluation and that Nix can't do, such as the furnish
coordinator or the Praxis runtime.

## Writing and verification

Use the technical-writing skill and Odyssey's
[writing guide](../odyssey/docs/writing.md) for docs and comments, and its
[Nix style](../odyssey/docs/reference/nix-style.md) for Nix code. Source comments
explain non-obvious constraints, use lowercase and contain no colons. Review all
comments in a touched file.

Test boundary behavior, failure paths, diagnostic order, selected-only evaluation
and state changes. Compare demanded projections rather than forcing opaque
results. Fix the cause of a failed invariant; don't add input-specific exceptions
or new flags to make a regression pass.

Retained tests are pure Nix, as nix-unit cases or Nix flake checks. A test may
use another language only when Nix can't express it, such as driving a real
terminal, a VM or a running process, and it states that reason. Python and other
scripts are fine as temporary probes while implementing. Keep them in `.runtime/`
and delete them before delivery.

Pure evaluation tests are nix-unit cases in the flake output `tests`, one node
per file under `tests/` (`tests.ownerships.engine."test ..."`), assembled in
`tests/default.nix`. Name each case for the one behavior it pins. Put the
demanded projection in `expr` and the value in `expected`; use `expectedError`
with `type` and a `msg` pattern that pins the diagnostic for failure paths.
nix-unit deep-forces `expr`, so never hand it an opaque payload or a derivation.
Builds, runtimes, VMs and live processes stay derivation flake checks. Run a
subtree with `nix-unit --flake path:.#tests.praxis`; `checks.unit` runs the whole
tree in the sandbox.

The development shell is devenv. Enter it with `devenv shell`, or run one command
with `devenv shell -- <command>`. Run the verbs with `devenv tasks run lexicon:fmt`,
`lexicon:check`, `lexicon:test` and `lexicon:gate`; `devenv test` runs the gate.
Each verb runs the flake's `lexicon-praxis` command of the same name, so the
Praxis project owns the commands, gate order and gate lock. `lexicon:test` runs
the nix-unit suite published as the flake output `tests`.

Run focused tests, then `devenv tasks run lexicon:gate`. The praxis commands read
`path:.`, which includes new files before staging. Never stage or commit without
the user approving the complete commit preview.
