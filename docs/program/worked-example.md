# Worked example: a Helix setup

The larger direct example has one recognizable purpose: install Helix, set its editor environment, publish its main configuration, and copy a small runtime query tree. It uses the same claim-free binding as the first lesson.

## Bind the target

<!-- source: ../../examples/program-studio/program-binding.nix -->
```nix
{ lexicon, system }:
# one fixed target keeps ordinary application declarations claim-free
lexicon.lib.programDirect {
  target = {
    host = {
      name = "studio";
      inherit system;
    };
    user.name = "river";
  };
}
```

The omitted host ID becomes `x86_64-linux/studio`; the omitted user home becomes `/home/river`.

## Describe the application

<!-- source: ../../examples/program-studio/helix.nix -->
```nix
{ program }:
program {
  pkg = pkgs: pkgs.helix;
  imports = [ { home.sessionVariables.EDITOR = "hx"; } ];
  nixos.environment.variables.EDITOR = "hx";
  files = [
    {
      dest = ".config/helix/config.toml";
      src = ./config.toml;
    }
  ];
  # query sources move as one tree while preserving their relative names
  directories = [
    {
      src = ./queries;
      dest = ".config/helix/runtime/queries";
    }
  ];
}
```

The application file contains only application capabilities. It does not repeat the target, resolver machinery, principal shape, or raw Furnish declaration fields.

## Wire both module graphs

The package and Home Manager import produce `helix.homeManager`:

<!-- source: ../../examples/program-studio/home.nix -->
```nix
{ helix, ... }:
{
  # the same declaration's Home Manager side carries its package and imports
  imports = [ helix.homeManager ];
  home.username = "river";
  home.homeDirectory = "/home/river";
  home.stateVersion = "26.05";
}
```

An existing Home Manager configuration uses that exact `imports` line. The example supplies `pkgs` and `helix` as module arguments, so importing `home.nix` evaluates `helix.homeManager` in the same graph without building or activating a Home Manager configuration.

The NixOS setting and file-producing capabilities produce `helix.nixos`:

<!-- source: ../../examples/program-studio/configuration.nix -->
```nix
{ helix }:
{
  # the combined declaration's NixOS side includes settings and file publication
  imports = [ helix.nixos ];
  lexicon.furnish.enable = true;
  # container scaffolding keeps the example buildable without host hardware
  boot.isContainer = true;
  networking.hostName = "studio";
  users.users.river.isNormalUser = true;
  system.stateVersion = "26.05";
}
```

Program imports Furnish only on the NixOS side because this declaration publishes files. Enabling Furnish is a host-level runtime decision; no raw declarations appear in the configuration.

## Inspect the combined result

From the Lexicon root:

```sh
nix eval --impure --json --file examples/program-eval.nix studio.result
```

<!-- program-value: studio.result -->
```json
{
  "destinations": [
    "/home/river/.config/helix/config.toml",
    "/home/river/.config/helix/runtime/queries/nix/highlights.scm",
    "/home/river/.config/helix/runtime/queries/python/highlights.scm"
  ],
  "editor": "hx",
  "homeDirectory": "/home/river",
  "homeStateVersion": "26.05",
  "homeUser": "river",
  "nixosEditor": "hx",
  "outputs": ["homeManager", "nixos"],
  "package": "helix"
}
```

The result is the union of the two demanded backends. The package, editor, username, home directory, and state version are read from the evaluated local Home Manager graph. The direct file becomes one symlink declaration. Directory expansion keeps both query files' paths relative to the declared query root.

## Build without activation

The example exposes a build-only check that forces the checked local Home Manager graph, the NixOS module graph, sparse outputs, and the generated manifest without realizing or switching a live host system:

```sh
nix flake lock
nix build --no-link .#checks.x86_64-linux.example
```

Run those commands from a copy of `examples/program-studio`, where `.#checks.x86_64-linux.example` refers to the example flake. The first command records the declared inputs. Neither command activates the result.

This example intentionally stops at one editor. Renderer backends, selection frameworks, and unrelated application policies stay in their focused pages rather than turning the configuration into a maximum-feature fixture.

[Program contents](README.md) · [Files and directories](files.md) · [Reference](reference.md)
