# Ownerships reference

This reference describes the factory exported by [flake.nix](../../flake.nix) and the functions returned by [src/ownerships/default.nix](../../src/ownerships/default.nix). The [advanced reference](advanced-reference.md) completes the policy and support-function contracts; [inspection](inspection.md#report-fields) documents report fields. These descriptions cover the current checkout, not a promise that every exported shape will remain unchanged.

## Factory

```nix
ownerships = lexicon.lib.ownerships { };
```

This binding is a snippet for a scope containing the Lexicon flake input. The [first lesson](getting-started.md) supplies that scope in a complete file.

The factory takes an attribute set. All fields are optional:

| Field | Value and default |
| --- | --- |
| `lib` | Nixpkgs library; defaults to Lexicon's pinned Nixpkgs library. |
| `axiom` | Axiom library value; defaults to the pinned Axiom factory applied with `lib`. |
| `krisis` | Krisis library value; defaults to the pinned Krisis factory applied with `lib` and `axiom`. |
| `descriptors` | `null` or a list of axis descriptors. `null` selects host, user, and `when`. A list replaces the defaults. |
| `relations` | `null` or a list of relation registrations. `null` selects host/user membership. A list replaces the defaults. |

Use the defaults for ordinary configuration. The last four fields support dependency substitution and [custom ownership rules](advanced-reference.md#custom-descriptors-and-relations).

## Declare a roster

`ownerships.define.host name` returns a host declaration. It also accepts a second argument: `ownerships.define.host name { system = "x86_64-linux"; }`. `name` is a string.

| Host field | Type | Default |
| --- | --- | --- |
| `system` | String | `"standalone"` |
| `dimensions` | Attribute set of dimension names to values | `{ }` |
| `aliases` | List of strings | `[ name ]` |

The declaration contains `kind = "host"`, `name`, `system`, `dimensions`, `aliases`, and `id = "${system}/${name}"`. The one-argument form also carries a callable `__functor`; use it as a declaration, not a JSON report.

`ownerships.define.user name { ... }` returns a user declaration. The second argument is required, even when it is `{ }`.

| User field | Type | Default |
| --- | --- | --- |
| `hosts` | `null` or list of host IDs/aliases | `null`, meaning unknown membership |
| `id` | String | `name` |
| `aliases` | List of strings | `[ name ]` |

The result contains `kind = "user"`, `name`, `hosts`, `id`, and `aliases`. Use nonempty, consistent names and identifiers; these constructors aren't general-purpose validation of arbitrary roster records.

`ownerships.toRoster declarations` takes a list of declarations and returns:

| Result field | Shape and meaning |
| --- | --- |
| `hosts`, `users` | Lists of unique canonical IDs, in declaration order. |
| `aliases.host`, `aliases.user` | Alias name → list of matching canonical IDs. |
| `display.host`, `display.user` | Canonical ID → display name. |
| `membership` | Canonical host ID → list of user IDs with known membership there. |
| `usersWithUnknownMembership` | User IDs from declarations with `hosts = null`. |
| `dimensions` | Dimension name → `{ members; byHost; }`, with unique values and a canonical host ID → value map. |

Repeated canonical IDs are combined, so repeated known user memberships are unioned. Display names and a host's value for a repeated dimension come from the last corresponding declaration. If any declaration for a user has unknown membership, that ID remains in `usersWithUnknownMembership` even if another declaration supplied known hosts.

## Host identity and membership

A host's canonical ID is `system/name`. With the default system, `define.host "laptop"` declares `standalone/laptop`. A host context uses `host.id` when present; otherwise it derives the ID from `host.system` (default `"standalone"`) and `host.name`. Context names aren't looked up as bare aliases. Use `host.id` when a claim alias or a multi-system roster could confuse that distinction.

Users similarly use `user.id` when present, otherwise `user.name`. Claim lists accept canonical IDs or unambiguous aliases. An alias with multiple matches fails; use the canonical ID. `aliases = [ ... ]` replaces the default aliases rather than adding to them.

A user's `hosts = null` means membership is unknown, while `hosts = [ ]` means known membership on no hosts. Unknown membership can keep a host/user claim potentially valid; it doesn't manufacture known matrix rows. Explicit host references in a user declaration must resolve to exactly one roster host. Unknown or ambiguous references fail during roster construction.

When both host and user claims are narrowed, there must be a compatible known pair, or a possible user with unknown membership. A host-only or user-only claim isn't a membership assertion. Ordinary resolution checks the claim's possibilities, not necessarily the supplied host/user pair; use a [strict resolver](#resolvers) to validate supplied identities and their membership too.

Set narrowing happens before alias expansion. Use the same spelling for an identity in parent and child claims: nesting `hosts = [ "laptop" ]` under `hosts = [ "standalone/laptop" ]` can be disjoint even though either spelling works by itself. Prefer canonical IDs consistently in a larger claim tree.

An effective include list needs at least one roster member. Unknown names mixed with a valid member can therefore survive; this isn't exhaustive typo detection for every name in a list. Unknown exclusions don't remove a known member. Ambiguous aliases still fail.

With the built-in descriptors, configuration-bearing units require nonempty host and user rosters, including in system scope. An empty built-in axis fails satisfiability even when its claim is global. This is distinct from requiring a user in a system context.

## Context

The default resolvers accept `{ host = ...; user = ...; }`. Each entity may be an attribute set or `null`; omitted entities become `null`. Host and user identity fields are described above. Other fields inside those entities are passed through, but unrelated top-level context fields are dropped. Roster dimensions and metadata aren't automatically copied into the context.

A missing entity is an error if any configuration-bearing unit narrows on that entity's axis, even if another claim would reject it. Fully global claims don't require entities. A predicate must cope with the context it reads and return a Boolean; exceptions and non-Booleans fail evaluation. In system scope, pass just `host` and write predicates accordingly.

## Unit fields

A unit is an attribute set. Non-reserved fields are its configuration, or you can put all configuration inside `value`.

| Field | Type and default | Behavior |
| --- | --- | --- |
| `hosts` / `exceptHosts` | List of strings; neither present means global | Include hosts or exclude them from the roster. Never both on one unit. |
| `users` / `exceptUsers` | List of strings; neither present means global | Include/exclude users. Forbidden anywhere in a system-scope unit tree. |
| `when` | Context → Boolean; absent means no extra predicate | Adds a condition in either scope. |
| `children` | List of unit attribute sets; `[ ]` | Children narrow the parent's claims. Parent data contributes before children, then later siblings. |
| `value` | Attribute set; absent means use inline configuration | Routes reserved-looking data keys, such as NixOS `users`, as ordinary payload. Can't be mixed with non-reserved inline fields. |
| `label` | Optional string | Diagnostic identity; preferred over `source`. Not inherited by children. |
| `source` | Optional string, not a Nix path value | Diagnostic location text; not read as a file and not inherited. |
| `mergeProfile` | Profile name string when profiling is enabled; absent | Selects a merge profile for this unit's own contribution. Not inherited. Ordinary resolvers reserve and remove it but don't enable or validate profiles. |

All claims on a unit must hold. Children intersect includes, accumulate exclusions, and combine predicates with logical AND. Nesting cannot widen a parent's claim. A unit with metadata but no nonempty payload or children is rejected; `{ }` is an empty no-op. `value = { }` alone is metadata-only, not a contribution.

Use `value` for reserved names. This is a snippet of a system-scope unit, not a complete NixOS configuration:

```nix
{
  hosts = [ "laptop" ];
  value.users.users.alice.isNormalUser = true;
}
```

A miss is inactive; an impossible effective set or incompatible known host/user claim is an error before selection, even for another context. Excluding every roster member or using an empty include can be impossible. A false predicate is a selection miss, not a proof that a unit's claim is impossible.

## Merge defaults

The ordinary resolvers merge selected units' data in parent-before-child, left-to-right order. Ordinary attribute sets merge recursively; lists concatenate in order without deduplication. Equal terminal values retain the first value, while differing terminals conflict. Derivations are terminals compared by `outPath`, not recursively merged. Functions aren't comparable and conflict when two contributors meet at that terminal. Different shapes also reach the terminal conflict rule. With no selected contributions, the result is `{ }`.

Merge errors identify the conflicting path and contributing unit identities. Default behavior doesn't interpret NixOS or Home Manager option types, priorities, or conditionals; see [using the result in a module](usage.md#use-the-result-in-a-module).

## Resolvers

`roster`, `units`, and `context` below are required arguments, in that order. `units` is a list of units; all declarations use the field and nesting rules above.

| Public function | Complete call shape | Result |
| --- | --- | --- |
| `mkResolve` | `mkResolve roster units context` | Merged data at user scope. |
| `mkResolveSystem` | `mkResolveSystem roster units context` | Merged data; rejects user claim keys throughout the tree. |
| `mkResolveStrict` | `mkResolveStrict roster units context` | User-scope data after validating supplied context identities and host/user membership. |
| `mkResolveSystemStrict` | `mkResolveSystemStrict roster units context` | Strict system-scope data; normally supply only a host. |
| `mkResolvePrepared` | `mkResolvePrepared roster units context` | User-scope data; bind `mkResolvePrepared roster units` once when evaluating many contexts. |
| `mkResolveSystemPrepared` | `mkResolveSystemPrepared roster units context` | Prepared system-scope data. |
| `mkResolveTrace` | `mkResolveTrace roster units context` | User-scope [trace record](inspection.md#report-fields). |
| `mkResolveSystemTrace` | `mkResolveSystemTrace roster units context` | System-scope trace record. |
| `mkResolveMatrix` | `mkResolveMatrix roster { units = units; }` | User-scope matrix over known memberships. |
| `mkResolveSystemMatrix` | `mkResolveSystemMatrix roster { units = units; }` | System-scope matrix over hosts. |
| `mkResolveProfiled` | `mkResolveProfiled profileArgs roster units context` | User-scope data with [merge policies](advanced-reference.md#merge-policies). |
| `mkResolveSystemProfiled` | `mkResolveSystemProfiled profileArgs roster units context` | System-scope data with merge policies. |

Strict mode rejects unknown supplied identities and incompatible known pairs even for a global unit. It still permits unknown membership and doesn't invent a requirement for an omitted entity on a global axis. It isn't a closed-world authorization check. Prepared variants reuse work for the same units; they return a context function, not a serialized cache.

Matrix arguments also accept `contextFor`. At user scope its type is `{ hostName, userName }: context`; at system scope it is `{ hostName }: context`. The names passed in are canonical IDs. Defaults return `{ host.id = hostName; user.name = userName; }` or `{ host.id = hostName; }`. Supply additional entity properties when predicates need them.

`mkResolvers roster` returns `resolve`, `resolveSystem`, `strict`, `systemStrict`, `prepared`, `systemPrepared`, `trace`, `systemTrace`, `matrix`, and `systemMatrix`, with the roster already bound. Its `profiled` and `systemProfiled` fields take `profileArgs`, then units and context. Its `resolverFor` field takes the configuration record below without `roster` or `base`; those are bound by the bundle.

`resolverFor { roster; scope ? "user"; projection ? "value"; strict ? false; profileArgs ? null; base ? ...; }` returns the chosen resolver. This is a signature, not a Nix expression to paste. `scope` is `"user"` or `"system"`; `projection` is `"value"`, `"prepared"`, `"trace"`, or `"matrix"`. The first three return `units: context: result`; matrix returns `{ units, contextFor ? ... }: report`. Unknown projections fail with an error. Stick to the two documented scopes; arbitrary scope strings aren't another supported mode.

`profileArgs = null` uses the ordinary merge; an attribute set enables profiles. `base` defaults to the roster-derived registry and checks. The expert override is documented under [support functions](advanced-reference.md#support-functions). `strict` validates per-context value, prepared, and trace projections; matrix projection uses its modeled contexts and doesn't apply that strict-mode wrapper.

## Import helpers

`importUnits { dir; args ? { }; }` takes a directory path and an optional attribute set of arguments. It recursively imports regular `.nix` files in sorted relative-path order. A file can return a unit, a list of units, or a function of `args` returning either. The return is one flat list; order within a file's list is preserved. Empty lists are allowed. Regular non-Nix files are ignored, but symlinks and other non-regular entries are rejected, including entries that don't end in `.nix`.

Imported units must be attribute sets. The importer checks that outer shape, not every claim or payload; resolver validation still applies. Syntax errors, missing function arguments, and exceptions in an imported file propagate. Directory discovery doesn't add a `source` label automatically.

`importUnitSets { dir; args ? { }; }` takes the same argument types and returns `{ home = [ ... ]; system = [ ... ]; }`. The notation here describes the return shape. At least one of `dir/home` and `dir/system` must be a directory; an absent collection becomes `[ ]`. Each present collection uses `importUnits`. A top-level `.nix` file is rejected as unclassified, an unknown top-level directory is rejected, and symlinks/non-regular entries are rejected. Non-Nix regular files at the root are ignored. `home` is the collection name; resolve it at user scope.

See [the file example](usage.md#reuse-declarations-from-files) for every file, binding, command, and result.

## Advanced and support exports

`define` and `toRoster` use the factory's descriptors. `mkRoster descriptors` creates `{ define; toRoster; }` for a supplied descriptor list. `translate` converts author units, `claimKeys` lists ownership fields, and `projectClaims` drops claims unavailable in a scope. Their exact shapes are in [support functions](advanced-reference.md#support-functions).

<!-- ownerships-exports: claimKeys define importUnitSets importUnits mkResolve mkResolveMatrix mkResolvePrepared mkResolveProfiled mkResolveStrict mkResolveSystem mkResolveSystemMatrix mkResolveSystemPrepared mkResolveSystemProfiled mkResolveSystemStrict mkResolveSystemTrace mkResolveTrace mkResolvers mkRoster projectClaims resolverFor toRoster translate -->
