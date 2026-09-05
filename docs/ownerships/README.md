# Ownerships

Ownerships selects and merges Nix values according to host, user, and other
ownership claims. It is a pure library: it does not install packages, manage
files, or execute commands.

## Resolve a small roster

Inside a consumer flake where `inputs` and `lib` are available:

```nix
let
  ownerships = inputs.lexicon.lib.ownerships { inherit lib; };
  roster = ownerships.toRoster [
    (ownerships.define.host "workstation" { system = "x86_64-linux"; })
    (ownerships.define.user "alice" { hosts = [ "workstation" ]; })
  ];
  doors = ownerships.mkResolvers roster;
in
doors.resolve [
  { value.editor = "helix"; }
  { users = [ "alice" ]; value.theme = "dark"; }
] {
  host.id = "x86_64-linux/workstation";
  user.name = "alice";
}
```

The result is `{ editor = "helix"; theme = "dark"; }`. Use it as ordinary data
or feed it into a NixOS/Home Manager module. Unselected payloads stay lazy.

## Guides

- [Usage](USAGE.md): rosters, units, contexts, exclusions, and module integration.
- [Resolver selection](doors.md): values, traces, prepared resolution, strict contexts, and matrices.
- [Reference](reference.md): claim fields and public functions.
- [Rosters and extension](rosters-and-extension.md): canonical identities, tags, and custom axes.
- [Inspection](inspection.md): selection traces and roster-wide reports.
- [Merge and provenance](merge-and-provenance.md): precedence, profiles, and explanation data.
- [Architecture](architecture.md): the selection pipeline and lazy boundaries.

## Integrations

Program uses Ownerships to select application configuration. Furnish can use
its resolvers to select file declarations. A Lexicon Den adapter can build a
roster from Den's host/user configuration. None of these is required to use the
resolver directly.

Praxis's optional [roster adapter](../praxis/adapters.md) turns host/user IDs
into parameter choices. It does not perform ownership resolution at runtime
or authorize the selected operation.
