# Registry API

`inputs.lexicon.lib.registry declaration` returns the fleet table and lookups.
Declaration records reject unknown fields.

| Field | Type | Default / requirement |
| --- | --- | --- |
| `root` | Nix path | Required |
| `runtimeRoot` | Absolute path string or null | Required; null means no live checkout |
| `hosts` | Attribute set keyed by host name | Required; `{}` permitted |
| `users` | Attribute set keyed by user name | Required; `{}` permitted |
| `den` | Den module argument or null | null; inherited fleet layer |
| `defaultSystem` | Non-empty string without `/`, or null | null |
| `dimensions` | Attribute set keyed by dimension name | `{}` |

Host, user and dimension names must be non-empty and contain no `/`.

## Records

| Host field | Type | Default / meaning |
| --- | --- | --- |
| `system` | Non-empty string without `/`, or null | Inherited Den system, then `defaultSystem`; missing final system is an error |
| `aliases` | Distinct non-empty string list, or null | Inherited aliases, then `[ name ]` |
| `dimensions` | Attribute set of strings | `{}`; overlays inherited dimensions |
| `users` | Attribute set of inline user declarations | `{}`; registers those users on this host |

`hosts.<name> = null` excludes a host supplied by Den. Excluding an undeclared
host fails. Inherited users lose the excluded membership; inherited users with
no remaining hosts are removed unless explicitly registered.

| User field | Type | Default / meaning |
| --- | --- | --- |
| `id` | Non-empty string or null | Inherited ID, then name |
| `aliases` | Distinct non-empty string list, or null | Inherited aliases, then `[ name ]` |
| `home` | Absolute path string or null | `"/home/${name}"` |
| `hosts` | Distinct non-empty host-name list, or null | Inherited/inline membership, then `[]` |
| `on` | Attribute set keyed by host name | `{}`; each value requires only `home` (absolute path string) |

Inline `hosts.<host>.users.<user>` records accept only `id`, `aliases`, `home`.
Their host membership is inferred. Top-level user declarations can override
the inline record fields. `on` may only name hosts in the user's membership.
User membership names registry host keys, not host aliases.

Each dimension accepts required `values` (distinct non-empty string list),
`required ? false`, `default ? null` (non-empty string or null). If dimensions
are declared, host dimension names and values are checked against that space;
required dimensions must be present after defaults. An empty dimension space
leaves inherited dimensions unrestricted.

Explicit non-null Lexicon fields override inherited Den fields. Host names must
be unique across systems. Aliases cannot identify multiple records in the same
entity namespace; user IDs must be unique.

## Result

| Attribute | Signature / value |
| --- | --- |
| `root`, `runtimeRoot` | Declaration values |
| `hosts`, `users` | Attribute sets keyed by registered names |
| `excluded` | Excluded host names |
| `host` | `nameOrAlias: hostRecord` |
| `user` | `nameOrIdOrAlias: userRecord` |
| `knows.host`, `knows.user` | `lookupName: bool` |
| `usersOn` | `hostNameOrAlias: userRecordList` |
| `hostsFor` | `userNameOrIdOrAlias: hostRecordList` |
| `homeFor` | `{ host, user }: absoluteHomeString`; checks membership |
| `hostsWhere` | `dimensionValues: hostRecordList`; all supplied values must match |
| `forSystem` | `system: hostRecordList` |
| `context` | `{ host, user ? null }`: `{ host = hostRecord; user = userRecord; }`, omitting user when null |
| `systems` | Sorted unique system list |
| `roster` | Compatible ownerships roster |
| `check` | true after forcing complete table validation |
| `summary` | `{ systems, hosts, users }`, each a sorted name list |

Host records contain `name`, `origin`, `system`, canonical `id = "system/name"`,
`aliases`, `dimensions`. User records contain `name`, `origin`, `id`, `aliases`,
`home`, sorted `hosts`, `homeByHost`. `origin` is `"den"`, `"lexicon"` or `"both"`.
Lookups reject unknown entities; membership-sensitive lookups reject a user
absent from the selected host. Registry host lookup indexes names and aliases;
its ownership roster uses canonical host IDs.
