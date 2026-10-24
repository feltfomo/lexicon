# Effects compatibility fixture

`tests/effects-contract.nix` checks the dependency adapter through native Krisis,
retained Axiom schemas, the public configured declaration factory and selected
Praxis manifests. Its `ok` projection evaluates the Boolean cases without
demanding opaque payloads.

The raw handler-state control must throw while the thunk-protected state and
returned value remain usable. Error reports omit their value. Independent errors
retain authored order, and an `Invalid` check suppresses its dependent callback.
Nested and sibling diagnostic scopes retain their own namespace and restore the
enclosing namespace. Handler collisions and unhandled effects fail explicitly.

The imported bookmarks extension lowers a resource through the public factory.
A separate extension observes injected diagnostic construction, rendering and
summary behavior. The public report and selected Praxis command also exercise
injected operations. The sibling Praxis declaration throws if demanded.
An injected Axiom identity renderer must remain visible through the public
configured factory. `controlExceptions` exposes malformed inspection, summary and
identity inputs for comparison with the retained old exception messages.

`callbackProbe` is a separate projection for callback-count observation. Evaluate
it once as JSON and retain stderr. It demands two references to the same parsed
record; `effects-contract parse` and `effects-contract normalize` must each occur
once. Ordinary `ok` evaluation doesn't emit these traces.

`callbackExceptions` exposes parse, normalize, formatter, dependent callback and
public lowering failures separately. Demand each relevant result projection and
retain the evaluator error text. Each must preserve its
`effects contract ... exception` message. A caught failure alone doesn't establish
exception-text preservation.

`sharedProbe` demands one cached Checked computation through two interpretations.
Its continuation trace must occur once. The Boolean suite also checks diagnostic
replay order, dependent suppression and opaque successful values. The public
structural-terminal fixture returns a sentinel from an injected reporter's
successful boolean check; that return must not replace the prepared entry.

Resource transport and callback observations are maintained by
`tests/furnish/observations.nix` and `contracts.py --family resources`.
`furnish-pure` also checks real NixOS module evaluation. Program boundary checks
include directory Checked expansion and theme file/Matugen preparation. These
projections demand identities and diagnostics while leaving unrelated source,
generator and executor payloads opaque.

The terminals family checks explicit reporter recovery separately from collecting
handler continuation. Furnish uses `fail` and `failOne` at their original return
positions. Theme file groups use `checked` on failure; Matugen demands each
registration `finish` return before constructing that group's declarations.
Public group probes preserve the first thrown diagnostic and leave later payloads
opaque when that terminal throws.
