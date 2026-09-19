# Program reference

This page records the public Program constructors, declaration shapes, defaults, conditional outputs, and author-visible failures. It describes the exported surface; internal compiler helpers are not public API.

## Public constructors

<!-- program-constructors: program programDirect programOwnerships programDen -->

### `programDirect`

```nix
program = lexicon.lib.programDirect {
  target = {
    host = {
      name = "studio";
      system = "x86_64-linux";
      id = "x86_64-linux/studio";
    };
    user = {
      name = "river";
      home = "/home/river";
    };
  };
};
```

Returns the Program declaration function bound to one fixed target. Claims are rejected. `target.user` may be omitted until a file-producing capability is used.

### `programOwnerships`

```nix
program = lexicon.lib.programOwnerships {
  roster = ownerships.toRoster [
    (ownerships.define.host "studio" { system = "x86_64-linux"; })
    (ownerships.define.user "river" { hosts = [ "studio" ]; })
  ];
};
```

Returns Program with Ownerships selection enabled. The roster must be the public attribute set produced by `ownerships.toRoster`.

### `programDen`

```nix
program = lexicon.lib.programDen {
  inherit den;
};
```

Returns Ownerships-backed Program using Lexicon's Den adapter for roster, file-principal, and host-user wiring. Den remains optional.

### `program`

```nix
program = lexicon.lib.program {
  resolve = ...;
  resolveSystem = ...;
  resolvePrepared = ...;
  filePrincipals = ...;
  hostUserNames = ...;
};
```

This compatible advanced constructor is for frameworks that already own those callbacks. See [advanced binding](advanced-reference.md).

## Direct target

<!-- program-target-fields: host user -->

| Target field | Requirement | Meaning |
| --- | --- | --- |
| `host` | Required attribute set | Fixed host identity used by every declaration |
| `user` | Optional attribute set or omitted | Fixed user identity used by Home Manager context and required for file publication |

Unknown target fields fail.

### Host fields

<!-- program-host-fields: name system id -->

| Host field | Requirement and default |
| --- | --- |
| `name` | Required nonempty string |
| `system` | Required nonempty string |
| `id` | Optional nonempty string; defaults to `${system}/${name}` |

The normalized host object is passed to function-form direct NixOS declarations and supplies the Furnish filesystem namespace for file-producing capabilities.

### User fields

<!-- program-user-fields: name home -->

| User field | Requirement and default |
| --- | --- |
| `name` | Required nonempty string when `user` is present |
| `home` | Optional absolute path; defaults to `/home/${name}` |

`user = null` and an omitted `user` both mean no user target. Package-only, Home Manager import-only, and NixOS-only declarations accept that shape. Nonempty `files`, nonempty `directories`, or a selected file-producing theme fail when no user is bound.

The direct target is the selection context. Module arguments named `host` or `user` do not override it. Direct NixOS content is emitted as ordinary imports, and its internal option names are opaque to Program claim validation.

## Binding modes and claims

<!-- program-claim-fields: hosts users exceptHosts exceptUsers when -->

The Program claim fields are `hosts`, `users`, `exceptHosts`, `exceptUsers`, and `when`.

| Binding | Claims | Selection context |
| --- | --- | --- |
| `programDirect` | Rejected | One fixed `target` |
| `programOwnerships` | Enabled | Module-provided canonical host and selected user |
| `programDen` | Enabled | Den-backed Ownerships context |
| Advanced `program` | Accepted | Defined by the supplied resolver callbacks |

Direct mode checks claim keys at the declaration, file, directory, directory-rule, theme, template, and renderer boundaries. Its diagnostic says the declaration activates every target and directs selection users to `programOwnerships`. Ordinary values inside `nixos`, including `users.users`, are not traversed by this check.

`programOwnerships` validates that the roster contains string lists at `roster.hosts`, `roster.users`, and `roster.usersWithUnknownMembership`, plus a `roster.membership` attribute set whose values are string lists. Use the [Ownerships reference](../ownerships/reference.md) for claim truth tables, aliases, nesting, strictness, and merge semantics.

## Program declaration

<!-- program-fields: hosts users exceptHosts exceptUsers when pkg nixos imports files directories theme -->

A bound constructor is called as `program { ... }` with these fields:

| Field | Shape | Default | Effect |
| --- | --- | --- | --- |
| `hosts` | List of host names | No claim | Binding-dependent selection |
| `users` | List of user names | No claim | Binding-dependent selection |
| `exceptHosts` | List of host names | No exclusion | Binding-dependent exclusion |
| `exceptUsers` | List of user names | No exclusion | Binding-dependent exclusion |
| `when` | Context predicate | No predicate | Binding-dependent selection |
| `pkg` | Function from `pkgs` to one package | Absent | Adds that package to `home.packages` |
| `nixos` | Module attribute set, module list, or function | Absent | Produces ordinary NixOS imports |
| `imports` | List of Home Manager modules | `[]` | Adds Home Manager imports |
| `files` | List of file entries | `[]` | Produces Furnish-backed NixOS publication |
| `directories` | List of directory entries | `[]` | Expands source trees into Furnish-backed files |
| `theme` | Theme attribute set | Absent | Produces renderer template and registration files |

The declaration vocabulary is closed. Unknown fields fail, with a nearest-field suggestion when one is close enough. A non-attribute declaration fails.

### `pkg`

Program calls `pkg pkgs` while evaluating its Home Manager module and wraps the returned package in a one-element `home.packages` list. Return one package, not a package list.

### `imports`

Program resolves the list for the current binding context and returns it as the `imports` of `homeManager`. The values are ordinary Home Manager modules.

### `nixos`

Accepted forms are:

```nix
nixos = { services.example.enable = true; };
```

```nix
nixos = [
  { services.example.enable = true; }
  ./another-module.nix
];
```

```nix
nixos = { pkgs, config, host, user, ... }: [
  { environment.systemPackages = [ pkgs.hello ]; }
];
```

A function receives `pkgs`, `config`, and the binding context's `host` and `user`. An attribute set becomes one slice; a list remains a list. Direct mode imports the slices without interpreting their module options. Selection-backed modes resolve Program claims attached to NixOS slices before importing the survivors.

## Conditional outputs

<!-- program-outputs: homeManager nixos -->

The only possible output names are `homeManager` and `nixos`.

| Demand | Emitted output |
| --- | --- |
| `pkg` is present | `homeManager` |
| `imports` is nonempty | `homeManager` |
| `nixos` is present | `nixos` |
| `files` is nonempty | `nixos` with Furnish and theme runtime imports |
| `directories` is nonempty | `nixos` with Furnish and theme runtime imports |
| A renderer backend is declared by `theme` | `nixos` with Furnish and theme runtime imports |
| Both Home Manager and NixOS demands exist | Both outputs |
| No demand exists | `{}` |

The `homeManager` output is a module function accepting `pkgs`, `lib`, and optional `host` and `user` arguments. It returns selected `imports` and the optional `home.packages` configuration.

The `nixos` output is a module function accepting `pkgs`, `config`, and optional `host` and `user` arguments. File-free direct content is returned as ordinary imports. File-producing content also imports Furnish runtime support, Matugen aggregation support, the selected NixOS slices, and generated declarations.

Constructing a binding has no runtime effect. Package-only, imports-only, and NixOS-only declarations do not import Furnish. File-producing declarations import the module, but reconciliation still follows the Furnish `lexicon.furnish.enable` option.

## Files

<!-- program-file-fields: hosts users exceptHosts exceptUsers when dest src label representation onConflict provenance -->

Each entry in `files` accepts:

| Field | Requirement and behavior |
| --- | --- |
| `dest` | Required nonempty string; normally a normalized home-relative destination |
| `src` | Required source value, lowered as a Furnish path source |
| `label` | Optional string; defaults to `files[<dest>]` |
| `representation` | Optional nonempty string; defaults to `symlink` |
| `onConflict` | Optional declared Furnish policy; omission compiles to `error` |
| `provenance` | Optional string passed as Furnish provenance source |
| Claim fields | Available only in selection-backed modes |

Program emits one declaration per selected file and selected user principal. It supplies the binding's canonical filesystem namespace, user authority, managed home, and source shape. A selected file with no user principal fails through the Program/Furnish boundary.

`representation = "symlink"` retains immutable artifact semantics. `representation = "writable"` creates a writable destination. `onConflict` accepts `"error"`, `"source-wins"`, and `"runtime-wins"`; their three-way behavior is defined in [Furnish usage](../furnish/usage.md).

Furnish performs final managed-root, destination, collision, executor, and retained-artifact validation. Program does not expose raw system-authority file declarations; its file helpers publish to selected user principals. Use raw Furnish for general system or non-application file lifecycle declarations.

## Directories and rules

<!-- program-directory-fields: hosts users exceptHosts exceptUsers when src dest exclude files representation onConflict provenance -->

A directory entry accepts:

| Field | Requirement and behavior |
| --- | --- |
| `src` | Required path or string naming a readable directory |
| `dest` | Required nonempty destination root |
| `exclude` | Optional list of normalized relative names; defaults to `[]` |
| `files` | Optional list of per-name rules; defaults to `[]` |
| `representation` | Optional default for expanded files |
| `onConflict` | Optional default for expanded files |
| `provenance` | Optional default for expanded files |
| Claim fields | Available only in selection-backed modes |

Directory sources are walked once per declared directory before user slices are resolved. Entries are traversed by sorted member name. Regular files are published; nested directories recurse. Other member kinds fail.

An `exclude` name prunes that exact member and, when it names a directory, its full subtree. Unknown names fail. Missing sources, non-directory sources, unreadable directories, and source members of unsupported kinds fail.

<!-- program-directory-rule-fields: hosts users exceptHosts exceptUsers when names representation onConflict provenance -->

Each entry in a directory's `files` list accepts:

| Field | Requirement and behavior |
| --- | --- |
| `names` | Required nonempty list of normalized relative member paths |
| `representation` | Optional override |
| `onConflict` | Optional override |
| `provenance` | Optional override |
| Claim fields | Available only in selection-backed modes and nested beneath the directory claim |

Rules reserve their names before expansion. Repeated, unknown, excluded, or theme-owned names fail. A selected rule overrides only its present lifecycle fields. An inactive rule does not fall back to a default declaration for the reserved file.

## Themes, templates, and renderers

<!-- program-theme-fields: hosts users exceptHosts exceptUsers when id renderers templates source output subdir placedAs subId reload native -->

`theme` accepts `id`, claim fields, `renderers`, `templates`, and the shared template value fields `source`, `output`, `subdir`, `placedAs`, `subId`, `reload`, and `native`.

`id` is required and must be one normalized basename. Two syntax forms are accepted:

- Single-template form: put `renderers` and optional shared value fields directly on `theme`.
- Template-list form: put template objects in `templates`. When `templates` is present, the outer theme object may contain only `id` and `templates`; top-level claim fields, `renderers`, and single-template value fields are forbidden mixed syntax. Put selection claims on individual template or renderer entries.

An empty `templates = [ ];` list is valid. It creates no renderer demand and, when the declaration contains nothing else, Program returns `{ }`.

<!-- program-template-fields: hosts users exceptHosts exceptUsers when source output subdir placedAs subId reload native renderers -->

Each template accepts:

| Field | Requirement and default |
| --- | --- |
| `source` | Required after renderer inheritance; path or string |
| `output` | Required after renderer inheritance; normalized relative path |
| `subdir` | Optional; defaults to the theme `id`; `null` or `""` means the template root |
| `placedAs` | Optional normalized basename; defaults to source basename |
| `subId` | Optional normalized basename or `null`; defaults to `null` |
| `reload` | Optional string or `null`; defaults to `null` |
| `native` | Optional attribute set; defaults to `{}` |
| `renderers` | Required nonempty attribute set |
| Claim fields | Available only in selection-backed modes |

<!-- program-renderer-fields: hosts users exceptHosts exceptUsers when source output subdir placedAs subId reload native sharedWith -->

A renderer override accepts the same claim and value fields plus `sharedWith`. Override values replace inherited template values. `sharedWith` defaults to `[]` and must contain unique known backend names, excluding the renderer itself. A backend may be assigned only once per template.

The registration ID is `id` when `subId` is absent, or `id-subId` when present. Duplicate registration IDs for a backend and principal fail. All template seeds are emitted as writable, `runtime-wins` Furnish files.

<!-- program-theme-backends: caelestia dms end4-pc illogical-impulse noctalia -->

The supported backend names are `caelestia`, `dms`, `end4-pc`, `illogical-impulse`, and `noctalia`.

| Backend | Template root | Additional behavior |
| --- | --- | --- |
| `caelestia` | `.config/caelestia/templates` | Generates one ordered strict publication hook per block; rejects nonempty `native` |
| `dms` | `.config/matugen/dms/templates` | Supports `native`; entries aggregate into `.config/matugen/config.toml` |
| `end4-pc` | `.config/end4-pc/matugen/templates` | Supports `native`; entries aggregate into `.config/end4-pc/matugen/config.toml` |
| `illogical-impulse` | `.config/illogical-impulse/matugen/templates` | Supports `native`; entries aggregate into `.config/illogical-impulse/matugen/config.toml` |
| `noctalia` | `.config/noctalia/templates` | Supports `native`; generates `.config/noctalia/<id>.toml` |

Unknown backend names fail and may suggest a close known name. Empty renderer sets, incomplete effective renderer values, unknown renderer fields, malformed or duplicate `sharedWith` values, self-sharing, and overlapping assignments fail.

Matugen-backed entries are grouped by renderer, filesystem namespace, authority scope, and authority identity. Each group generates one configuration because Matugen has no include/merge mechanism.

## Selection, ordering, and laziness

Selection-backed declarations preserve Ownerships behavior:

- unclaimed values are global;
- host and user claims select matching contexts;
- exclusions and `when` predicates narrow selection;
- nested file, directory-rule, template, and renderer claims cannot escape their parent selection;
- inactive payloads remain lazy;
- NixOS slices select canonical host contexts;
- each selected user file is lowered for one user principal.

List order is preserved through resolver merges unless a declared Ownerships merge policy changes it. Directory walking uses sorted names. Theme registration grouping is deterministic, and Caelestia hook entries are ordered by registration ID. Furnish performs final destination collision checks.

## Author-visible failures

Program reports grouped declaration errors. Important failure families include:

- malformed declarations and unknown declaration fields;
- non-function `pkg`, non-list `imports`, `files`, or `directories`, and invalid `nixos` forms;
- missing or invalid direct target fields;
- direct-mode claim use, with help pointing to `programOwnerships`;
- file-producing direct declarations without `target.user`;
- missing file fields or undeclared conflict policies;
- unreadable, missing, or non-directory sources;
- unknown exclusions and invalid or conflicting directory rules;
- malformed themes, templates, renderers, placement paths, sharing, native data, and duplicate registrations;
- selected files that reach no user principal;
- downstream Furnish manifest, collision, and runtime diagnostics.

Validation is demand-driven. A malformed selected payload fails when its output is evaluated; an inactive Ownerships payload remains unforced. Evaluation and build errors do not imply that a host was activated.

## Public boundary

The four constructors above are public flake exports. Program's internal field schemas, directory walker, unit builders, report helpers, theme adapters, binding records, and Matugen module are implementation details. Do not import them as stable API.

[Program contents](README.md) · [Common usage](usage.md) · [Advanced binding](advanced-reference.md)
