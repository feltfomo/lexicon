# Den adapter API

`inputs.lexicon.lib.den { inherit den; }` returns the attributes below. `den`
is the evaluated Den module argument.

| Attribute | Signature | Meaning |
| --- | --- | --- |
| `roster` | Attribute set | Ownership roster over every system in `den.hosts` |
| `hostUserNames` | `{ system, host }` | User names registered on that host |
| `filePrincipals` | `{ system, host, user ? null }` | One user principal for `user.name`, or `[]` at host scope |
| `hostPrincipals` | `{ system, host }` | System principal followed by every registered user principal |
| `hostAspects` | `system` | Attribute set mapping each host name to its named top-level includes |
| `topLevelAspectNames` | `hostEntity` | Names of that entity's top-level `aspect.includes` |
| `drop` | `names`, then `includes` | Includes list with the named top-level aspects removed |
| `mkTarget` | `{ system, host, transformIncludes ? (includes: includes) }` | Standalone instantiated host configuration |

A host context has `{ id = "system/host"; name = "host"; system = "system"; }`.
A user principal has `authority = { scope = "user"; identity = userName; }`
and `ctx = { host = hostContext; user.name = userName; }`. A system principal
has `authority = { scope = "system"; identity = "system/host"; }` and
`ctx.host = hostContext`.

`roster` includes host dimensions, canonical host IDs, user names, aliases,
display names and host-user membership. Den users have known membership.
Roster construction does not evaluate the host's NixOS configuration.

`filePrincipals` selects the user under whom a module was resolved. It does not
assign that module's files to every user on the host. `hostPrincipals` enumerates
possible authorities for pure projections and collision checks.

`drop` rejects any name absent from the supplied top-level includes. Nested
aspects cannot be dropped by name through this API. Nameless includes remain.

`mkTarget` transforms a copy of the host aspect and resolves it with Den's host
scope handlers. It supplies `nixpkgs.hostPlatform` at default priority. It assumes
standalone host resolution matches flake-root resolution; hosts that collect
across the fleet need a different resolution root. It does not replace the
canonical `nixosConfigurations` output.
