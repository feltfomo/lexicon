# Ownerships

Ownerships is a targeting layer for plain Nix values. A unit declares who owns
it; the resolver composes nested claims, validates the result, selects the
leaves matching one build context, and merges the survivors.

It is an ordinary Nix library. Den and Program are integrations built on it,
not requirements. Nothing here knows about NixOS options, `mkDefault`,
`mkForce`, or submodule merging — Ownerships runs *before* the module system
and hands it a finished attrset.

## The idea

```nix
[
  { packages = [ pkgs.git ]; }
  {
    hosts = [ "khion" ];
    packages = [ pkgs.nvtopPackages.nvidia ];
  }
  {
    users = [ "feltfomo" ];
    programs.helix.enable = true;
  }
]
```

Each config-bearing attrset is a **unit**. A unit may carry ownership claims,
children, identity metadata, and a merge profile. No claim means global.

Resolve that list against a host and user and you get one merged value. The
four outcomes for any leaf are:

- **selected** — it applies and contributes to the merge;
- **inactive** — the claim is valid but does not match this context;
- **impossible** — the claim cannot match the roster at all;
- **conflict** — selected co-owners disagree.

Inactive is normal. Impossible is an error even when the current context would
not have selected it anyway, because it means the declaration is wrong rather
than merely idle.

## Using it by itself

You need a roster, a resolver, units, and a context:

```nix
let
  ownerships = import ./src/ownerships { inherit lib krisis axiom; };

  roster = ownerships.toRoster [
    (ownerships.define.host "khion" { system = "x86_64-linux"; })
    (ownerships.define.user "feltfomo" { hosts = [ "khion" ]; })
  ];

  resolve = ownerships.mkResolve roster;
in
resolve units {
  host = {
    name = "khion";
    system = "x86_64-linux";
  };
  user.name = "feltfomo";
}
```

The roster is the finite model claims are validated against. Ownerships does
not discover machines or accounts from NixOS — an unknown host in a claim is an
error, not an empty selection.

[Usage](USAGE.md) covers standalone Nix, NixOS without Den, Home Manager
without Den, and loading units from a directory tree.

## With Program

When the Program layer is available, an aspect should use it. It wraps all
of this:

```nix
den.aspects.example = program {
  hosts = [ "khion" ];
  pkg = pkgs: pkgs.example;
  files = [
    {
      src = "./configs/example/config.toml";
      dest = ".config/example/config.toml";
    }
  ];
};
```

Reach for the injected `resolve` or `resolveSystem` only when Program's bounded
fields do not fit the configuration you are writing.

## Documentation

- [Usage](USAGE.md) — standalone, NixOS, Home Manager, unit trees
- [Doors](doors.md) — `resolverFor`, the projections, the generated names
- [Architecture](architecture.md) — the pipeline
- [Merge and provenance](merge-and-provenance.md) — how survivors combine
- [Rosters and extension](rosters-and-extension.md) — descriptors, relations, new axes
- [Trace and matrix inspection](inspection.md) — debugging selection
- [Reference](reference.md) — grammar, facade, errors, glossary

## Source map

| File | Responsibility |
| --- | --- |
| `surface.nix` | Author syntax, scope guards, and the resolver carrier. |
| `resolve.nix` | Bind descriptors, relations, registries, stages, and rosters. |
| `engine.nix` | Compose, validate, select, trace, and merge pipeline. |
| `axes.nix` | Claims, descriptors, aliases, scopes, and relation registrations. |
| `roster.nix` | Descriptor-driven standalone roster construction. |
| `merge.nix` | Tracked merge, profiles, locks, and provenance. |
| `matrix.nix` | Read-only projection across modeled contexts. |
| `import-units.nix` | Deterministic unit-file discovery and scope grouping. |
| `default.nix` | Export the supported facade. |

## Verification

```fish
nix fmt
nix flake check -L
```
