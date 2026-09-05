# Roster-backed choices

Praxis accepts ordinary parameter declarations. It has no dependency on Den
and does not discover a fleet at runtime. The optional `praxisAdapters` factory
converts a roster's host and user identities into parameter choices.

## Ownerships

```nix
let
  ownerships = inputs.lexicon.lib.ownerships { inherit lib; };
  roster = ownerships.toRoster [
    (ownerships.define.host "workstation" { system = "x86_64-linux"; })
    (ownerships.define.user "alice" { hosts = [ "workstation" ]; })
  ];
  adapters = inputs.lexicon.lib.praxisAdapters { inherit lib; };
  choices = adapters.fromRoster roster;
in
{
  parameters = [
    (choices.host // { required = true; short = "H"; })
    (choices.user // { required = true; short = "u"; })
  ];
  steps = [ {
    exec = [ "inspect-target" { param = "host"; } { param = "user"; } ];
  } ];
}
```

`fromRoster` reads `roster.hosts` and `roster.users`, sorts them, and returns
`host` and `user` parameter fragments. Host choices preserve canonical IDs such
as `x86_64-linux/workstation`; the adapter does not shorten them or guess a
platform. Types, descriptions, defaults, and short flags remain normal Praxis
fields that the caller can override.

These are independent enums. They do not assert that a selected user belongs
to a selected host. If the operation requires that relationship, validate it in
your command or expose only valid pairs as a single choice.

## Den

Pass an existing Lexicon Den adapter, not Den's internal configuration:

```nix
choices = adapters.fromDen denAdapter;
```

This is equivalent to `adapters.fromRoster denAdapter.roster`. Lexicon's Den
adapter remains the only component that extracts Den's roster. Praxis core
only sees the resulting choices. The caller owns roster freshness and any
command that acts on the selected identity.
