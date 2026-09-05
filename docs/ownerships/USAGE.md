# Using Ownerships

## Define the roster

Use the public factory from a consumer flake. This example is a function you
can save as `ownership.nix`:

```nix
{ lexicon, lib }:
let
  ownerships = lexicon.lib.ownerships { inherit lib; };
  roster = ownerships.toRoster [
    (ownerships.define.host "workstation" { system = "x86_64-linux"; })
    (ownerships.define.host "laptop" { system = "aarch64-linux"; })
    (ownerships.define.user "alice" { hosts = [ "workstation" "laptop" ]; })
    (ownerships.define.user "sam" { hosts = [ "workstation" ]; })
  ];
in
{
  inherit ownerships roster;
  doors = ownerships.mkResolvers roster;
}
```

Bind it with:

```nix
ownership = import ./ownership.nix { lexicon = inputs.lexicon; inherit lib; };
```

Host identity includes the platform, such as `x86_64-linux/workstation`. Short
host names are useful when unambiguous; canonical IDs avoid ambiguity in a
mixed-platform roster. The roster also records actual host/user membership.
See [rosters and extension](rosters-and-extension.md) for tags and custom axes.

## Select ordinary values

A unit contains a value and optional claims. Untagged units apply globally:

```nix
let
  units = [
    { value.editor = "helix"; }
    { users = [ "alice" ]; value.theme = "dark"; }
    { hosts = [ "aarch64-linux/laptop" ]; value.battery = true; }
  ];
  ctx = {
    host.id = "x86_64-linux/workstation";
    user.name = "alice";
  };
in
ownership.doors.resolve units ctx
```

This returns `{ editor = "helix"; theme = "dark"; }`. The laptop-only value is
inactive. Ownerships returns data; the caller decides where to use it.

`hosts` and `users` restrict selection. `exceptHosts` and `exceptUsers` exclude
identities from the enclosing scope. `when` adds a context predicate. An inner
unit narrows its parent's claim and cannot select outside it.

Keep large or host-specific payloads inside the selected unit. Inactive values
remain lazy, so selecting one context does not require unrelated package or
filesystem data.

## Resolve system configuration

Use the system resolver when the receiving module is host-wide:

```nix
ownership.doors.resolveSystem [
  { value.services.openssh.enable = true; }
  {
    hosts = [ "x86_64-linux/workstation" ];
    value.services.printing.enable = true;
  }
] {
  host.id = "x86_64-linux/workstation";
}
```

System resolution rejects user-axis claims; it does not guess which user a
host-wide option belongs to. Keep user configuration in a user-scoped resolve.

A NixOS module can return the resolved value directly. Supply the roster and
context through the module's arguments or close over them when building the
module. Ownerships does not infer a canonical host from a machine nickname.

## Reuse a unit list

For one list resolved in several contexts:

```nix
resolveEditor = ownership.doors.prepared editorUnits;
aliceEditor = resolveEditor aliceContext;
samEditor = resolveEditor samContext;
```

Prepared resolution shares context-independent work and applies selection to
each supplied context. Use `strict` instead of `resolve` when an invalid or
unrostered context should fail even for globally selected units.

The [resolver guide](doors.md) lists trace, prepared, strict, and matrix entry
points with their call shapes.

## Inspect a selection

```nix
trace = ownership.doors.trace units ctx;
report = ownership.doors.matrix { inherit units; };
```

Use a trace to understand one context and a matrix to inspect the roster.
Neither installs the returned values. [Inspection](inspection.md) describes the
report and diagnostic projections.

Merge behavior is a separate concern from selection. Do not use a strict
context resolver to change precedence. For merge profiles and provenance, see
[merge and provenance](merge-and-provenance.md).

## Connect other libraries

**Furnish** can use `doors.resolve` and `doors.resolveSystem` to select file
declarations. Or perform selection yourself and pass only untagged declarations
to its disabled provider. [Furnish usage](../furnish/USAGE.md) covers both paths.

**Program** uses the same resolvers for application declarations and
`doors.prepared` for repeated application contexts. It adds package/module and
file authoring, not another ownership model.

**Den** can supply a roster through Lexicon's Den adapter. Keep the adapter at
the integration boundary; core declarations should use canonical identities and
claims rather than reaching into Den's host/user representation.

**Praxis** can turn the roster into host/user parameter choices through an
[optional adapter](../praxis/adapters.md). These choices do not resolve claims
or establish that any selected host/user pair is valid.

## Common mistakes

- A host name collides across platforms: use the canonical platform/name ID.
- A user is not on the target host: check roster membership and context, not
  only the spelling of the username.
- A system resolve contains a user claim: move it to user scope or explicitly
  project the claims before building the system unit.
- A field is not in the returned value: inspect the trace for the actual context.
- A value merged differently than expected: inspect merge policy separately
  from the selector that made the unit active.
