# Registry reference

Registry compiles one fleet declaration into a normalized host and user table, an Ownerships roster, and bound lookup helpers. It is pure Nix data. It does not create accounts, instantiate hosts, generate operating-system configurations, or run commands.

## Constructor

### `lexicon.lib.registry declaration`

Compiles a declaration. The declaration may be imported from `lexicon.nix` or supplied directly.

```nix
registry = lexicon.lib.registry (import ./lexicon.nix);
```

A declaration may also carry a `den` input. See [Inherit a Den fleet](den.md).

## Declaration fields

The root declaration is closed. Unknown fields fail with a Registry diagnostic and, when possible, a suggested field name.

| Field | Default | Meaning |
| --- | --- | --- |
| `root` | required | A Nix path containing the configuration source, or `null`. |
| `runtimeRoot` | required | An absolute string naming a live configuration checkout, or `null`. |
| `hosts` | required | Host inventory keyed by bare host name. |
| `users` | required | Users declared once for the whole fleet. |
| `defaultSystem` | `null` | System used by hosts that do not name one. |
| `dimensions` | `{ }` | Declared space of host classifications. |
| `den` | `null` | An optional Den input layered under this declaration. |

`root`, `runtimeRoot`, `hosts`, and `users` are checked by presence rather than by value. Writing `runtimeRoot = null;` or `users = { };` is required; omitting the key fails with `runtimeRoot-missing` or `users-missing` so that an empty answer is stated rather than assumed.

`root` accepts a Nix path, not a string. `runtimeRoot` accepts an absolute string, not a Nix path. Registry never converts one into the other.

### `dimensions.<name>`

| Field | Default | Meaning |
| --- | --- | --- |
| `values` | `[ ]` | The permitted values for this dimension. |
| `required` | `false` | Whether every host must carry a value. |
| `default` | `null` | Value applied to hosts that omit this dimension. |

Declaring a dimension space closes the world: an unknown dimension name on a host fails with `unknown-dimension`, an undeclared value fails with `dimension-value`, and a missing required value fails with `dimension-required`. Each of those diagnostics suggests a close spelling when one exists.

Declaring no dimensions at all disables dimension checking entirely. Host classifications are then opaque strings passed through to the roster.

### `hosts.<name>`

Host names must be non-empty and cannot contain `/`. The name and system form the canonical host id `<system>/<host>`.

| Field | Default | Meaning |
| --- | --- | --- |
| `system` | `defaultSystem` | The Nix system for this host. |
| `aliases` | `[ <name> ]` | Unique, non-empty aliases used for lookup. |
| `dimensions` | `{ }` | Host classifications. |
| `users` | `{ }` | Users registered on this host. |

A host with no `system` and no `defaultSystem` fails with `host-system-missing`.

Writing `hosts.<name> = null;` excludes a host contributed by the Den layer. Excluding a name no layer declares fails with `exclude-no-match`, and asking for an excluded host afterwards fails with `host-excluded` rather than offering the removed name as a suggestion.

### `hosts.<name>.users.<user>`

A user written under a host is the same registration written from the other side: it adds membership, and optionally a home there, without a second top-level entry.

| Field | Default | Meaning |
| --- | --- | --- |
| `id` | `<user>` | Canonical user identity shared across host declarations. |
| `aliases` | `[ <user> ]` | Unique, non-empty user aliases. |
| `home` | `/home/<user>` | Absolute home path on this host. |

### `users.<name>`

| Field | Default | Meaning |
| --- | --- | --- |
| `id` | `<name>` | Canonical user identity. |
| `aliases` | `[ <name> ]` | Unique, non-empty user aliases. |
| `home` | `/home/<name>` | Default home path across hosts. |
| `hosts` | `[ ]` | Hosts this user is registered on. |
| `on.<host>.home` | `home` | Per-host home override. |

If one `id` appears under different user names, Registry fails with `user-id-conflict` instead of choosing one display name. The same id may have a different home on each host; the normalized user record records those paths in `homeByHost`.

## Result fields

| Field | Meaning |
| --- | --- |
| `root` | The validated source root or `null`. |
| `runtimeRoot` | The validated live root or `null`. |
| `hosts` | Normalized host records keyed by bare name. |
| `users` | Normalized user records keyed by bare name. |
| `excluded` | Host names removed by `hosts.<name> = null`. |
| `systems` | Sorted systems present in the table. |
| `roster` | The canonical Ownerships roster. |
| `summary` | `{ systems; hosts; users; }`, all sorted name lists. |
| `host name` | One host record by name or alias. |
| `user name` | One user record by name, id, or alias. |
| `knows.host name` | Whether a host name or alias resolves. |
| `knows.user name` | Whether a user name, id, or alias resolves. |
| `usersOn host` | User records registered on one host. |
| `hostsFor user` | Host records one user is registered on. |
| `homeFor { host; user; }` | The home path for that pair. |
| `hostsWhere selector` | Host records matching a dimension selector. |
| `forSystem system` | Host records for one system. |
| `context args` | A validated host and optional user selection. |
| `check` | Forces the whole table and returns `true`. |

### Normalized records

Each host record carries `name`, `origin`, `system`, `id`, `aliases`, and `dimensions`. Each user record carries `name`, `origin`, `id`, `aliases`, `home`, `hosts`, and `homeByHost`.

`origin` records which layers produced the record, so a host inherited from Den and refined in `lexicon.nix` is distinguishable from a purely local one.

```nix
{
  name = "river";
  origin = "lexicon";
  id = "river";
  aliases = [ "river" ];
  hosts = [ "workstation" ];
  homeByHost.workstation = "/home/river";
}
```

### `context`

```nix
registry.context {
  host = "workstation";
  user = "river";
}
```

`host` is required and may be a name or alias. `user` is optional and may use a declared name, canonical id, or alias. There is no `system` argument: a host name already identifies one host in the table.

The result contains a canonical `host` record and, when requested, a canonical `user` record. Unknown hosts, unknown users, excluded hosts, and users not registered on the selected host all fail before a consumer runs.

### `hostsWhere`

```nix
servers = registry.hostsWhere { role = "server"; };
```

Every selector key must be a declared dimension when a dimension space exists; a typo fails with `unknown-dimension` rather than silently matching nothing.

### Praxis ownership

Registry does not build Praxis records. Compose them from the parts it already exposes:

```nix
ownership = {
  inherit (registry) roster;
  scope = "system";
  context = registry.context { host = "workstation"; };
};
```

## Subsystem boundaries

- Ownerships consumes `registry.roster`.
- Program binds with `lexicon.lib.programOwnerships { roster = registry.roster; }`.
- Praxis can consume `registry.root`, a composed `ownership` record, and `registry.hostsWhere` while retaining its own runtime-root and command fields.
- Furnish remains independent and benefits through Program when an application declares files.

All standalone constructors remain public. Registry is shared data, not a mandatory wrapper.

## Diagnostics

Registry uses closed Axiom schemas and Krisis diagnostics under the `registry` code prefix. Independent malformed host and user entries are reported together. Name clashes between hosts, users, and aliases are one gate every lookup passes through rather than a per-record check.

## File convention

`lexicon.nix` is the recommended home for a declaration because it makes the shared facts easy to find. Lexicon never discovers that file automatically. Any ordinary Nix value accepted by `registry` has the same meaning.

[Registry contents](README.md) · [Den integration](den.md) · [Back to the manual](../README.md)
