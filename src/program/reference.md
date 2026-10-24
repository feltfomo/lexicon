# Program compatibility API

New declarations use [Lexicon factories](../lexicon/reference.md). These exports
translate legacy syntax into that compiler. Native module results may use imports
where the former compiler used config; evaluate them through their module system.

All constructors return `spec: aspect`. Optional aspect attributes are
`homeManager` and `nixos`.

Registered compilation uses shared native reporting internally. Legacy field
callbacks and native modules retain their ordinary Nix return values; callers do
not supply an effect argument. Dependency overrides still participate in target
diagnostics and terminal normalization.

| Constructor | Required arguments | Selection |
| --- | --- | --- |
| `inputs.lexicon.lib.program` | `resolve`, `resolveSystem`, `resolvePrepared`, `filePrincipals`, `hostUserNames` | Caller-supplied ownership resolvers and principals |
| `inputs.lexicon.lib.programDen` | `den` | Den roster and resolved user |
| `inputs.lexicon.lib.programOwnerships` | `roster` | Ownership roster and module `host`/`user` context |
| `inputs.lexicon.lib.programDirect` | `target` | Every declaration active for the explicit target |

`programOwnerships.roster` is the result of `ownerships.toRoster`. Required
roster fields are `hosts`, `users`, `membership`, `usersWithUnknownMembership`.

`programDirect.target` accepts only `host` and optional `user`:

| Field | Type | Default |
| --- | --- | --- |
| `host.name` | Non-empty string | Required |
| `host.system` | Non-empty string | Required |
| `host.id` | Non-empty string | `"${host.system}/${host.name}"` |
| `user` | Attribute set or null | null |
| `user.name` | Non-empty string | Required when user is supplied |
| `user.home` | Absolute path string | `"/home/${user.name}"` |

Direct targets reject unknown fields. Files, links, directories and file-producing
themes require `target.user`, including callbacks that return empty lists.
Direct declarations reject ownership claims, including nested file,
directory-rule and theme claims. Legacy direct NixOS slices are opaque native modules, including functions and paths.
Ownership-bound slices retain Ownerships merging and its conflicting-scalar errors.

## Declaration

The declaration is closed: unknown fields are errors.

| Field | Type | Meaning when present |
| --- | --- | --- |
| `pkg` | `pkgs: package` | Package added to `home.packages` |
| `imports` | List of Home Manager modules | Home Manager imports, including module files; default `[]` |
| `homeManager` | Module attribute set or function | Inline Home Manager module |
| `nixos` | Unit, list of units, or function returning either | System configuration slices |
| `files` | List or context function returning a list | Home-relative managed files; default `[]` |
| `links` | List or context function returning a list | Live links without retaining target contents; default `[]` |
| `directories` | List or context function returning a list | Expanded managed file trees; default `[]` |
| `theme` | Theme declaration | Renderer template registrations |
| `hosts`, `users`, `exceptHosts`, `exceptUsers`, `when` | Ownership claims | Narrow the declaration |

A `nixos` function receives `{ pkgs, config, host, user }`. Its returned units
use the ownership unit vocabulary. Ownership-bound system slices reject `users` and
`exceptUsers`; put a NixOS `users` configuration attribute under `value`.
Legacy direct slices remain opaque native modules.
The declaration's host claim wraps its system slices. User claims select home
payloads and files but are projected out of the system wrapper.

`homeManager` is emitted for `pkg`, non-empty `imports`, or a `homeManager` module. `nixos` is emitted
for `nixos` or file- or link-producing declarations. Managed files are reconciled through
the NixOS Furnish runtime. Destinations belong to the selected user principal;
a file declaration reaching no user principal fails an assertion.

## Context and Home Manager modules

File callbacks receive `{ pkgs, config, host, user }` from the NixOS slice.
The declaration's ownership claims select the slice before callbacks run.
Entries returned by callbacks support the same nested claims and validation as
static lists. Direct bindings reject claims in callback results too. Static
directory lists share their directory inventory across user slices; a directory
callback walks its selected sources within each slice.

`homeManager` uses the native module system. Module functions can request `pkgs`,
`config`, `lib`, or arguments supplied through `specialArgs` and `_module.args`.
Module attributes such as `imports`, `options`, `config`, and `_module` retain
their normal meaning. Its declaration claims select the entire module.
`programDirect` binds `host` and `user` to its target for the `homeManager`
function itself, overriding runtime arguments for these two names. Nested
imported modules receive their normal module arguments. Ownership and Den
bindings use the selected module context.

```nix
program {
  links = { user, ... }: [
    {
      target = "/home/${user.name}/Projects/skills/subphase-orchestrator";
      dest = ".codex/skills/subphase-orchestrator";
    }
  ];
  homeManager = { pkgs, ... }: {
    home.packages = [ pkgs.git ];
  };
}
```

[`examples/program-skills/skills.nix`](../../examples/program-skills/skills.nix)
combines a system-indexed source tree, editable skill links, and a Home Manager
bootstrap service in one declaration. The canonical example receives the bound `lexicon` function and `sources`,
an attribute set keyed by Nix system whose values are skill directories.

## Files

| Field | Type | Default / meaning |
| --- | --- | --- |
| `src` | Source accepted by the file materializer | Required; normally a Nix path, store path string or generated file derivation |
| `dest` | Non-empty string | Required; relative to the selected user's home, or absolute beneath that home |
| `label` | String | `"files[${dest}]"` |
| `representation` | Non-empty string | `"symlink"`; bundled runtime also supports `"writable"` |
| `onConflict` | `"error"`, `"source-wins"`, `"runtime-wins"` | `"error"` |
| `provenance` | String | Source label for diagnostics |
| Ownership claims | Claim fields | Narrow this file |

`symlink` publishes a link to the retained source. `writable` publishes a writable
copy. `onConflict` governs divergence from managed state, not duplicate
declarations: two declarations for the same filesystem identity always fail.

## External links

`links` declares links to mutable paths outside the Nix store:

```nix
links = [
  {
    target = "/home/alice/Projects/skills/subphase-orchestrator";
    dest = ".claude/skills/subphase-orchestrator";
  }
];
```

An entry accepts `target`, `dest`, optional `label` and `provenance`, and the usual ownership claims. `target` must be a normalized absolute string without store context. Nix path values are rejected so evaluation cannot import a checkout accidentally. Targets may be absent and may name files or directories. Furnish manages the link text and never reads or copies the target. Source edits are visible immediately without activation.

External links use the same user selection, destination collision checks, ownership ledger, publication and retirement as files. Direct bindings reject ownership claims on links just as they do on files. A declaration cannot link a destination to itself. Writable copies and directory expansion belong to `files` and `directories`.

Matching pre-existing links remain unowned. During migration, verify and remove only the exact old links before activation so Furnish can publish and record them from absence. Never remove their source checkout. Removing an owned declaration retires only its unchanged destination link.

## Directories

| Field | Type | Default / meaning |
| --- | --- | --- |
| `src` | Path or string naming an existing directory | Required |
| `dest` | Non-empty string | Required destination directory |
| `exclude` | List of normalized relative member paths | `[]`; a directory entry excludes its subtree |
| `files` | List of per-name rules | `[]` |
| `representation`, `onConflict`, `provenance` | File lifecycle fields | Defaults inherited by expanded files |
| Ownership claims | Claim fields | Narrow the directory |

A per-name rule accepts only `names`, lifecycle fields and ownership claims.
`names` is a required non-empty list of normalized relative file paths.
Rules override lifecycle defaults. A name reserved by a rule is omitted from
the default expansion even when that rule is inactive for the current context.

The walk is recursive and deterministic. Symlinks and other special members
are rejected unless excluded. Unknown exclusions, unknown rule names,
duplicate reserved names and rules for excluded files fail validation.
Selected theme sources under a directory are omitted from its ordinary file
expansion; excluding or overriding those theme sources is an error.
Normalized relative paths reject leading `/`, empty components, `.` and `..`.
Empty or untracked directories may be absent from a git-backed flake source.

## Diagnostic API

`inputs.lexicon.lib.report {}` returns:

| Attribute | Signature / meaning |
| --- | --- |
| `problem` | Diagnostic factory, default severity `error`, code prefix `program` |
| `reporter` | Krisis reporter with `checked`, `finish` and rendering/failure operations |
| `finish` | Finish a validation result, throwing rendered diagnostics on failure |
| `suggest` | `candidateNames: name: nearestNameOrNull` |
| `editDistance` | Krisis edit-distance function |
| `duplicateValues` | `stringList: sortedDuplicateNames` |
| `suggestionFor` | `candidateNames: name: diagnosticHintString` |
