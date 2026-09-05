# Praxis

Declare project commands in Nix. Run them as ordinary executables.

Praxis runs programs, live scripts, and other declared commands in order. It
stops at the first failure and preserves its exit code. It doesn't need NixOS,
Home Manager, Ownerships, or a particular directory layout. The runner targets
Linux; Nix is needed to build its packages, not to dispatch an installed command.

## Start with one command set

Add Lexicon to your flake:

```nix
inputs.lexicon = {
  url = "github:feltfomo/lexicon";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

In a flake-parts `perSystem` function, with `inputs` in scope:

```nix
perSystem = { pkgs, ... }:
  let
    tasks = inputs.lexicon.lib.praxis {
      inherit pkgs;
      discoverRoot = "flake.nix";
      commands = {
        fmt = "nix fmt";
        check = "nix flake check -L";
        gate = [ { command = "fmt"; } { command = "check"; } ];
      };
    };
  in {
    apps = tasks.apps;
    packages = tasks.packages // { praxis = tasks.package; };
    devShells.default = pkgs.mkShell { packages = [ tasks.package ]; };
  };
```

These example commands expect your project to provide a formatter and checks.
They use the caller's `nix` or `lix`; Praxis doesn't replace it. Lexicon supplies
Axiom and Krisis internally, so you don't add those as consumer inputs.

```fish
nix run .#gate
nix develop
gate
praxis plan gate
```

`discoverRoot` starts at the caller's directory and walks upward to the nearest
marker. Omit it to keep caller-relative behavior. `cwd` is a runtime string,
not `./.` or another Nix path. Each step gets its own process; a `cd` or export
inside one step doesn't leak into the next.

## Split by responsibility, compile once

The [usage guide](praxis/usage.md) shows all three layouts: declarations in
`flake.nix`, a standalone `praxis.nix` containing the whole command set, and
[one file per command](praxis/usage.md#one-file-per-command). The latter keeps
both commands and project settings outside the flake. Only output wiring stays
there, or in a separate flake-parts adapter. All three use the same options and
compile to the same manifest.

- [Usage](praxis/usage.md) covers arguments, scripts, composition, and installation.
- [Reference](praxis/reference.md) lists fields, outputs, scope, and exit statuses.
- [Architecture](praxis/architecture.md) explains the validation and runner boundaries.

`praxis plan` prints the expanded command without executing it. It isn't a
dry-run implementation for arbitrary programs. Nothing retries, resumes, or
rolls back a partially completed command.
