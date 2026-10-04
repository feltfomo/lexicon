# Program API

All constructors return `spec: aspect`. Optional aspect attributes are
`homeManager` and `nixos`.

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

Direct targets reject unknown fields. Files, directories and themes require
`target.user`. Direct declarations reject ownership claims, including nested
file, directory-rule and theme claims. Direct NixOS slices concatenate lists,
recursively merge attribute sets and take the last other value.

## Declaration

The declaration is closed: unknown fields are errors.

| Field | Type | Meaning when present |
| --- | --- | --- |
| `pkg` | `pkgs: package` | Package added to `home.packages` |
| `imports` | List of Home Manager modules | Home Manager imports; default `[]` |
| `nixos` | Unit, list of units, or function returning either | System configuration slices |
| `files` | List of file entries | Home-relative managed files; default `[]` |
| `directories` | List of directory entries | Expanded managed file trees; default `[]` |
| `theme` | Theme declaration | Renderer template registrations |
| `hosts`, `users`, `exceptHosts`, `exceptUsers`, `when` | Ownership claims | Narrow the declaration |

A `nixos` function receives `{ pkgs, config, host, user }`. Its returned units
use the ownership unit vocabulary. System slices reject `users` and
`exceptUsers`; put a NixOS `users` configuration attribute under `value`.
The declaration's host claim wraps its system slices. User claims select home
payloads and files but are projected out of the system wrapper.

`homeManager` is emitted only for `pkg` or non-empty `imports`. `nixos` is emitted
for `nixos` or file-producing declarations. Managed files are reconciled through
the NixOS Furnish runtime. Destinations belong to the selected user principal;
a file declaration reaching no user principal fails an assertion.

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
