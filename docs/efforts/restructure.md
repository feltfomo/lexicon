# Restructure effort

This effort moves Lexicon from today's `src/` layout to the layered design in
[the philosophy](../philosophy.md). It drops Axiom, makes Krisis the only diagnostic engine, gives
every subsystem one record shape and static settings, adds a composition subsystem and a plain host
so Lexicon works without Den, adds an evaluation benchmark suite, and moves development to devenv
and nix-unit. skadi keeps evaluating unchanged on the day each band lands.

- [Capabilities](../reference/capabilities.md): what Lexicon provides once the effort is done.
- [Architecture](../explanation/architecture.md): owners, the compile pipeline, invariants, the
  Krisis contract, the benchmark suite, the file mapping and the approved decisions.
- [Audit](../records/restructure-audit.md) and [research proposal](../records/restructure-proposal.md):
  the evidence behind the design.

## Owner and plan

The lexicon restructure team owns this effort. Its roadmap, bands, phases and baton live outside
the repository in `~/Documents/Plans/Lexicon/`, whose primary copy is on lumi.

## Decisions

The owner approved every recommendation in the architecture's decisions table on 2026-10-27,
D1 to D19, including consumer API changes P1 to P4. Everything the capabilities page promises
ships by the end of this effort. Each promise is Current or assigned to a band, and a promise
leaves the page only through an owner-approved change, never by deferral.

## Bands and merge order

Each band runs in its own worktree and branch, `restructure/<band>`, and lands on `main` as one
merge in this order. Bands on the same line can run at the same time.

| Order | Band | Repository | Depends on |
| --- | --- | --- | --- |
| 0 | Tooling: devenv, nix-unit, the bug they exposed | lexicon | none |
| 1 | Krisis batch 1 (K1, K4, K5, K6, K7, K9) and the benchmark suite | krisis, lexicon | 0 |
| 2 | Native Krisis in Lexicon, one dependency owner; Krisis batch 2 (K2, K3, K8) | lexicon, krisis | 1 |
| 3 | Axiom removed | lexicon | 2 |
| 4 | Target layout and architecture tests, no behavior change | lexicon | 3 |
| 5 | Subsystem records, settings with host binding, assembly, hosts, aliases, P1 to P3 | lexicon | 4 |
| 6 | Composition subsystem, quirks and the plain host | lexicon | 5 |
| 7 | Pure-Nix cleanup, the format registry with TOML and JSON, P4, kernel audit | lexicon | 6 |

## Interfaces this effort changes

- `inputs.lexicon.lib` gains `configure`, `hosts.den` and `flake`. Every current entry point stays
  as an alias until skadi stops using it and one release has carried it (D11).
- Extension records become subsystem records. The `extensions` alias converts old records once (D4).
- Diagnostic codes move into per-subsystem catalogs (`furnish/...`, `theme/...`, `native/...`).
- Krisis gains K1 to K9, and K10 only if spike S5 shows duplicate diagnostics.

## Limits

| Limit | Waits on | Until then |
| --- | --- | --- |
| Untagged unions and homogeneous attribute sets are still checked by Lexicon code | Krisis batch 2 (K2, K3), band 2 | Band 2's Lexicon track keeps the existing checks for those shapes and removes them when the batch lands |
| Den walks includes under the Den host; only the portable aspect subset is checked against the plain walker | none, approved as permanent (D1) | Not a limit. Recorded here so it isn't reopened |
