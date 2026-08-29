# doors

a door is a resolver built for one roster. there is one carrier, `resolverFor`,
and every named door is a row in a table over it.

## resolverFor

```nix
resolverFor {
  roster,
  base ? resolveLib.engineArgsFor roster,
  scope ? "user",
  projection ? "value",
  strict ? false,
  profileArgs ? null,
}
```

`scope` is `user` or `system`. it decides which claim keys a unit is allowed to
carry and which context builder the matrix projection uses. a unit that carries
a key its scope cannot bind is reported by name rather than ignored, and every
offending key in the tree is named, not just the first.

`projection` is one of four.

| projection | returns |
| --- | --- |
| `value` | the merged value, the ordinary door |
| `trace` | the merged value plus the selection, context and survivor traces |
| `prepared` | a resolver with translate and compose already done, re-run per context |
| `matrix` | the fleet view, every context resolved at once |

`strict` validates the build context against the roster before resolving. an
unknown host name, an unknown user name, and a host and user pair that cannot
co-exist are all errors. a user whose host membership is unknown is rescued
rather than rejected, since the roster does not claim to know where it lives.

the validation runs before the resolve body, not from inside the context. a
globally owned unit narrows on nothing and never demands the context, so a
check hung off the context thunk would never run for exactly the declarations
that are hardest to reason about.

`profileArgs` is passed through to the merge profile when the roster's units
select one. an unknown profile name is reported with the nearest legal one.

`base` exists so a caller can compile the descriptor set once and hand the same
compiled set to several doors. `mkResolvers` does exactly that.

## mkResolvers

```nix
let doors = mkResolvers myRoster;
in doors.resolve ctx
```

builds every door for a roster over one compiled descriptor set. prefer it
whenever a call site needs more than one projection, which is most inspection
code.

## the named doors

| name | scope | projection | strict |
| --- | --- | --- | --- |
| `mkResolve` | user | value | no |
| `mkResolveSystem` | system | value | no |
| `mkResolveTrace` | user | trace | no |
| `mkResolveSystemTrace` | system | trace | no |
| `mkResolvePrepared` | user | prepared | no |
| `mkResolveSystemPrepared` | system | prepared | no |
| `mkResolveMatrix` | user | matrix | no |
| `mkResolveSystemMatrix` | system | matrix | no |
| `mkResolveStrict` | user | value | yes |
| `mkResolveSystemStrict` | system | value | yes |

they are generated from that table rather than written out, so a name and its
behaviour cannot drift apart. a combination the table does not name is reachable
by calling `resolverFor` directly.

`mkResolveProfiled` and `mkResolveSystemProfiled` stay curried with the profile
arguments first, because that is how their call sites read.

## adding a projection

add a row to the projections table. the named doors, the scope guard and the
unknown projection message all pick it up.
