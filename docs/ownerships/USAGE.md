# Using Ownerships

Ownerships selects and merges configuration by host, user, and predicate
claims. It is a plain Nix library — Den and Program are integrations on top of
it, not requirements.

Three ways in, all using the same claims and the same machinery:

1. **Pure Nix** — build a roster, make a resolver, resolve ordinary values.
1. **NixOS or Home Manager without Den** — return resolved config from a normal
   module.
1. **Program or Den** — use Program, or the resolvers Den injects.

## Quick start

```nix
let
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;

  ownerships = import ./src/ownerships { inherit lib krisis axiom; };

  roster = ownerships.toRoster [
    (ownerships.define.host "khion" { system = "x86_64-linux"; })
    (ownerships.define.user "feltfomo" { hosts = [ "khion" ]; })
  ];

  resolve = ownerships.mkResolve roster;
in
resolve
  [
    { shared = true; }
    {
      hosts = [ "khion" ];
      desktop = true;
    }
    {
      users = [ "feltfomo" ];
      editor = "helix";
    }
  ]
  {
    host = {
      name = "khion";
      system = "x86_64-linux";
    };
    user.name = "feltfomo";
  }
```

The result is an ordinary value:

```nix
{
  shared = true;
  desktop = true;
  editor = "helix";
}
```

Nothing here touches Den, aspects, NixOS modules, or Home Manager.

## What you have to supply

Den normally wires these together. Standalone, they are yours:

- the Ownerships facade;
- a roster naming every host and user your claims mention;
- a resolver, user-scope or system-scope;
- the units;
- the concrete context.

Ownerships does not read machines or accounts out of NixOS. The roster is the
finite model claims are checked against, which is why an unknown host is an
error rather than an empty result.

## Building a roster

```nix
roster = ownerships.toRoster [
  (ownerships.define.host "khion" { system = "x86_64-linux"; })
  (ownerships.define.host "lumi" { system = "aarch64-linux"; })
  (ownerships.define.user "feltfomo" { hosts = [ "khion" "lumi" ]; })
  (ownerships.define.user "guest" { hosts = [ "khion" ]; })
];
```

A host's canonical identity is `<system>/<name>`, so `khion` above is
`x86_64-linux/khion`. Claims may use either the canonical ID or a unique bare
alias. `define.host "khion"` with no system is valid and lands under
`standalone/khion`; prefer an explicit system for real machines.

User membership defines which host and user pairs are possible. A host and a
user can both exist while that particular pairing does not.

If two systems define the same bare name, the alias is ambiguous and claims
must use canonical IDs. Unknown and ambiguous members are declaration errors,
not inactive claims.

`toRoster` uses the built-in host and user descriptors. `mkRoster` is the
lower-level constructor for custom descriptor sets.

## Scopes

**User scope** (`mkResolve`) receives both entities:

```nix
{
  host = {
    name = "khion";
    system = "x86_64-linux";
  };
  user.name = "feltfomo";
}
```

**System scope** (`mkResolveSystem`) receives only a host, and recursively
rejects `users` and `exceptUsers`. Use it for NixOS configuration that does not
represent one person.

## Claims

| Key | Value | Scope |
| --- | --- | --- |
| `hosts` | host aliases or canonical IDs | user and system |
| `exceptHosts` | host aliases or canonical IDs | user and system |
| `users` | user IDs or unique aliases | user only |
| `exceptUsers` | user IDs or unique aliases | user only |
| `when` | context predicate | user and system |

No claim means global. Include and exclude are opposite polarities of one axis,
so do not set `hosts` with `exceptHosts`, or `users` with `exceptUsers`, on the
same unit.

```nix
[
  { programs.fish.enable = true; }
  {
    hosts = [ "khion" "lumi" ];
    home.sessionVariables.FLEET = "personal";
  }
  {
    exceptUsers = [ "guest" ];
    programs.git.enable = true;
  }
]
```

### Predicates

Use `when` only when roster identity cannot express the condition:

```nix
{
  when = { host, ... }: host.gpu == "nvidia";
  home.packages = [ pkgs.nvtopPackages.nvidia ];
}
```

A false predicate is inactive, not impossible — matrix projection cannot prove
arbitrary code is always false. Prefer named claims when names suffice; they
validate against the roster and reason better in the fleet report.

### Nesting

Children inherit their parent's claim and may narrow it, never widen it:

```nix
{
  hosts = [ "khion" "lumi" ];
  children = [
    { home.sessionVariables.EXAMPLE = "1"; }
    {
      hosts = [ "khion" ];
      home.packages = [ pkgs.example-desktop-tools ];
    }
  ];
}
```

A parent may hold both payload and children; its own payload becomes one leaf
and each config-bearing descendant becomes another. Disjoint parent and child
claims are impossible declarations, not quiet non-selections.

### Reserved keys and `value`

The grammar reserves the claim keys plus `children`, `value`, `label`,
`source`, and `mergeProfile`. When your payload itself starts with one of those
— NixOS `users.*` is the usual case — route it through `value`:

```nix
{
  hosts = [ "khion" ];
  value = {
    users.users.example = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
  };
}
```

Claims, metadata, and children stay outside `value`. Inline payload keys cannot
coexist with it. Content inside `value` is opaque and is not rescanned for
ownership-looking keys.

### Identity metadata

```nix
{
  label = "khion audio tools";
  source = "configuration/units/audio.nix";
  hosts = [ "khion" ];
  environment.systemPackages = [ pkgs.pavucontrol ];
}
```

`label` and `source` show up in diagnostics, traces, and provenance. They never
enter resolved configuration and do not inherit. Worth setting in any
nontrivial collection, so a failure points back at a file you wrote.

## Loading units from a directory

```text
units/
├── shared.nix
├── desktop.nix
└── hosts/
    ├── khion.nix
    └── lumi.nix
```

```nix
units = ownerships.importUnits {
  dir = ./units;
  args = { inherit pkgs; };
};
```

Each file returns one unit or a list of them, and function files receive
`args`:

```nix
{ pkgs }:
[
  { services.openssh.enable = true; }
  {
    hosts = [ "khion" ];
    environment.systemPackages = [ pkgs.helix ];
  }
]
```

Files are sorted by relative path before import, so ordered list concatenation
is deterministic. Non-Nix files are ignored; symlinks and unknown entry types
are rejected rather than followed.

The importer assigns no scope — you choose the resolver.

### Mixed system and home trees

A plain attrset does not reveal which module system owns it, so a mixed tree
needs an explicit boundary:

```text
units/
├── system/
│   └── hosts/khion.nix
└── home/
    └── users/feltfomo.nix
```

```nix
unitSets = ownerships.importUnitSets {
  dir = ./units;
  args = { inherit pkgs; };
};

systemConfig = resolveSystem unitSets.system { inherit host; };
homeConfig = resolve unitSets.home { inherit host user; };
```

Either directory may be absent, giving an empty list. At that root, loose
`.nix` files and unknown directories are errors.

## NixOS without Den

Ownerships resolves plain attrsets, so a normal module can return one:

```nix
{ lib, pkgs, hostName, hostSystem, ... }:
let
  ownership = import ./ownerships.nix { inherit lib krisis axiom; };
  unitSets = ownership.importUnitSets {
    dir = ./units;
    args = { inherit pkgs; };
  };
in
ownership.resolveSystem unitSets.system {
  host = {
    name = hostName;
    system = hostSystem;
  };
}
```

A flake or `lib.nixosSystem` caller supplies `hostName` and `hostSystem`
through `specialArgs`.

Ownerships selects and merges first; the module system processes the resulting
options afterward. Do not treat it as a replacement for NixOS option merging —
resolve units that produce normal module configuration.

## Home Manager without Den

Home Manager uses user scope, since both host and user claims can matter:

```nix
{ lib, pkgs, ... }:
let
  ownership = import ./ownerships.nix { inherit lib krisis axiom; };
  unitSets = ownership.importUnitSets {
    dir = ./units;
    args = { inherit pkgs; };
  };
in
ownership.resolve unitSets.home {
  host = {
    name = "khion";
    system = "x86_64-linux";
  };
  user.name = "feltfomo";
}
```

## A shared setup file

Worth centralizing the roster and the doors once:

```nix
# ownerships.nix
{ lib, krisis, axiom }:
let
  ownerships = inputs.lexicon.lib.ownerships { inherit lib krisis axiom; };

  roster = ownerships.toRoster [
    (ownerships.define.host "khion" { system = "x86_64-linux"; })
    (ownerships.define.user "feltfomo" { hosts = [ "khion" ]; })
  ];
in
{
  inherit ownerships roster;
}
// ownerships.mkResolvers roster
// {
  inherit (ownerships) importUnits importUnitSets;
}
```

`mkResolvers` hands back every door for that roster over one compiled
descriptor set, so `resolve`, `resolveSystem`, `strict`, `trace`, and `matrix`
all share the same compilation instead of each redoing it. Prefer it whenever a
project needs more than one projection. See [doors](doors.md).

## Merge behaviour

The default profile deep-merges attrsets, concatenates lists in source order,
keeps equal scalars, rejects differing scalars, compares derivations by
`outPath`, and treats functions as unequal.

```nix
resolve [
  { packages = [ pkgs.git ]; }
  { packages = [ pkgs.helix ]; }
] ctx
```

gives one list in declaration order. Whereas:

```nix
resolve [
  { editor = "helix"; }
  { editor = "vim"; }
] ctx
```

fails, before the module system ever sees it. Reach for
`mkResolveProfiled` only when your system intentionally defines merge-profile
behaviour. See [merge and provenance](merge-and-provenance.md).

## Strict doors

Ordinary resolvers validate authored claims and demand only the context axes
those claims actually narrow. That keeps global and host-only units lazy, but
it also means a context you never look at is never checked.

Strict doors validate the supplied context itself against the roster first:

```nix
resolveStrict = ownerships.mkResolveStrict roster;
```

An unknown host, an unknown user, or a pair that cannot co-exist is an error.
A user whose membership is unknown is rescued rather than rejected, because the
roster does not claim to know where they live.

Use strict at entry points where the context arrives from outside and must be
real — not to change selection. A successful strict resolve produces exactly
what the ordinary door would.

## Debugging

`mkResolveTrace` explains one context: which leaves survived, which axes
rejected the rest, which stages ran, and lazily, who contributed to each merged
path.

`mkResolveMatrix` explains the fleet: selection across every modeled context,
which leaves are provably dead, which are never selected anywhere, and how two
hosts differ. It does not merge payloads. See [inspection](inspection.md).

## Troubleshooting

**Unknown host or user.** Declare it in the same roster you passed to the
resolver. Nothing is discovered automatically.

**Ambiguous host alias.** Use `<system>/<name>`, or make the bare name unique.

**Missing user context.** Use `mkResolveSystem` for system-only units. A user
resolver needs a user once a selected claim narrows that axis.

**System scope rejects `users`.** Move the unit into user resolution or use a
host claim. System scope has no user entity. The error names every offending
key, not just the first.

**Matching values still conflict.** Ownerships merges plain values, not module
definitions. Two different scalar writes conflict before NixOS option merging
would have reconciled them.

**A child never selects.** Check the intersection with its parent. Children
narrow inherited ownership and cannot escape it.

**An odd context passes global units.** Expected — ordinary resolution only
validates demanded axes. Use a strict door if every supplied entity must be
roster-valid.

**An imported file has an invalid result.** Each file must return one unit
attrset or a list of them. The error names the relative path and the offending
type.

**A mixed tree cannot classify a file.** Put every `.nix` file under `system/`
or `home/`. Payload keys are never used to guess.

## With Program and Den

Where the Program layer is available, it stays the preferred surface:

```nix
den.aspects.example = program {
  hosts = [ "khion" "lumi" ];
  users = [ "feltfomo" ];
  pkg = pkgs: pkgs.example;
  directories = [
    {
      src = "./configs/example";
      dest = ".config/example";
    }
  ];
};
```

For configuration Program's vocabulary does not cover, Den injects resolvers
already bound to the fleet roster:

```nix
{ resolve, resolveSystem, ... }:
{
  den.aspects.example.homeManager =
    { host ? null, user ? null, pkgs, ... }:
    resolve [
      { programs.example.enable = true; }
      {
        hosts = [ "khion" ];
        home.packages = [ pkgs.example-helper ];
      }
    ] { inherit host user; };
}
```

Same semantics throughout. Standalone callers build the roster, Den supplies
roster-bound doors, Program supplies the higher-level facade.
