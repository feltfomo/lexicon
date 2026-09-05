# Choosing an Ownerships resolver

Bind a roster once, then select the projection you need:

```nix
doors = ownerships.mkResolvers roster;
value = doors.resolve units ctx;
```

`units` is the list of ownership-tagged values. `ctx` identifies the build host
and, for user scope, the user. Binding the roster does not bind either of those
arguments.

| Resolver | Scope | Result |
| --- | --- | --- |
| `resolve` | User | Merged value |
| `resolveSystem` | System | Merged value; rejects user-scoped claims |
| `trace` | User | Selection and merge trace |
| `systemTrace` | System | Selection and merge trace |
| `prepared` | User | Prepared `units -> ctx -> value` resolver |
| `systemPrepared` | System | Prepared system resolver |
| `matrix` | User | Report across the roster's host/user contexts |
| `systemMatrix` | System | Report across host contexts |
| `strict` | User | Value after validating the context against the roster |
| `systemStrict` | System | System value with roster context validation |

`strict` validates the supplied context. It does not change merge precedence or
turn a widening merge into an error. Scope rules and merge policy are separate
choices.

## Resolve one context

```nix
doors.resolve [
  { value.editor = "helix"; }
  { users = [ "alice" ]; value.theme = "dark"; }
] {
  host.id = "x86_64-linux/workstation";
  user.name = "alice";
}
```

For repeated use of the same units, bind the prepared resolver:

```nix
resolveApplication = doors.prepared applicationUnits;
alice = resolveApplication aliceContext;
sam = resolveApplication samContext;
```

Preparation shares context-independent work; selection still happens for each
context. It does not eagerly force inactive payloads.

## Inspect several contexts

```nix
report = doors.matrix { inherit units; };
```

Matrix calls take a record, not `units ctx`. Supply `contextFor` when the default
host/user projection does not match your context shape. See
[inspection](inspection.md) for the report fields.

## Customize a combination

`doors.resolverFor` accepts `scope`, `projection`, `strict`, and `profileArgs`.
The roster is already bound. `doors.profiled profileArgs` and
`doors.systemProfiled profileArgs` provide value resolvers with custom merge
profiles. See [merge and provenance](merge-and-provenance.md) before changing
merge policy.

The individual factories (`mkResolve`, `mkResolveSystem`, `mkResolvePrepared`,
`mkResolveTrace`, and their strict/matrix variants) remain available when you
only need one resolver. They have the same behavior as the corresponding
member of `mkResolvers roster`.
