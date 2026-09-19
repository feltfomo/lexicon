# Get started with Program

This path uses `programDirect`. It has no Den input, Ownerships roster, resolver callback, or principal callback. The first application capability is one ordinary NixOS setting; file publication comes after the first result.

Run the checkout commands on this page from the Lexicon repository root. They evaluate or build immutable results and do not activate a host.

## Bind one target

Put the one-time binding in `program-binding.nix`:

<!-- source: ../../examples/program-minimal/program-binding.nix -->
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

`target.host.name` and `target.host.system` identify the fixed host. Because `target.host.id` is omitted, Program uses `x86_64-linux/studio`. Because `target.user.home` is omitted, it uses `/home/river`. The user is not needed for the first NixOS setting, but including it makes the same binding ready for the file step later.

The binding is inert. It only returns the `program` function that application files call.

## Declare one application setting

`paperkite.nix` receives the bound function and uses the small application-facing shape:

<!-- source: ../../examples/program-minimal/paperkite.nix -->
```nix
{ program }:
program {
  # ordinary NixOS options remain opaque to Program's claim validation
  nixos.environment.variables.PAPERKITE_MODE = "focused";
}
```

The `nixos` value is ordinary NixOS module content. A normal option such as `users.users` is equally valid here; direct-mode claim validation does not inspect inside this module value.

## Wire the emitted output

The declaration contains `nixos`, so it emits `paperkite.nixos`. `configuration.nix` imports that output into the NixOS module graph:

<!-- source: ../../examples/program-minimal/configuration.nix -->
```nix
{ paperkite }:
{
  # the declaration emits nixos, so its module belongs in the NixOS graph
  imports = [ paperkite.nixos ];
  # container scaffolding keeps the example buildable without host hardware
  boot.isContainer = true;
  networking.hostName = "studio";
  users.users.river.isNormalUser = true;
  system.stateVersion = "26.05";
}
```

The complete flake exposes the binding to `paperkite.nix` and passes the resulting module to the configuration:

<!-- source: ../../examples/program-minimal/flake.nix -->
```nix
{
  description = "A first claim-free Program declaration";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    {
      nixpkgs,
      lexicon,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      program = import ./program-binding.nix { inherit lexicon system; };
      paperkite = import ./paperkite.nix { inherit program; };
      demo = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ (import ./configuration.nix { inherit paperkite; }) ];
      };
    in
    {
      nixosConfigurations.demo = demo;
      checks.${system}.example = pkgs.runCommandLocal "program-minimal-example" { } (
        assert demo.config.environment.variables.PAPERKITE_MODE == "focused";
        "touch $out"
      );
      # these values exist for the documentation tests, not for a real configuration
      lib.result = {
        mode = demo.config.environment.variables.PAPERKITE_MODE;
        outputs = builtins.attrNames paperkite;
        furnishIntegration = demo.options ? lexicon.furnish;
      };
    };
}
```

## Evaluate the first result

From the Lexicon root, evaluate the projected result:

```sh
nix eval --impure --json --file examples/program-eval.nix minimal.result
```

<!-- program-value: minimal.result -->
```json
{
  "furnishIntegration": false,
  "mode": "focused",
  "outputs": ["nixos"]
}
```

Only `nixos` exists. This declaration has no package, Home Manager import, or file-producing capability, so Program does not import Furnish.

## Make a predictable edit

In `examples/program-minimal/paperkite.nix`, change `PAPERKITE_MODE` from `"focused"` to `"quiet"`. The output names and Furnish state stay the same; only `mode` changes.

The changed result is:

```sh
nix eval --impure --json --file examples/program-eval.nix minimal.changed
```

<!-- program-value: minimal.changed -->
```json
{
  "furnishIntegration": false,
  "mode": "quiet",
  "outputs": ["nixos"]
}
```

Restore `"focused"` before continuing with the checkout example.

## Add an application file

A Program file entry needs only its application-relative destination and source. The complete focused declaration is:

<!-- source: ../../examples/program-files/files.nix -->
```nix
{ program }:
program {
  files = [
    {
      # program supplies namespace, authority, managed root, and source shape to Furnish
      dest = ".config/paperkite/settings.conf";
      src = ./sources/settings.conf;
    }
  ];
}
```

File-producing Program declarations emit `nixos`. Import that output and enable reconciliation on the host:

<!-- source: ../../examples/program-files/configuration.nix -->
```nix
{ declaration }:
{
  # file-producing declarations expose the NixOS module that imports Furnish
  imports = [ declaration.nixos ];
  # activation remains an explicit host choice even though declarations are lowered automatically
  lexicon.furnish.enable = true;
  # container scaffolding keeps the example buildable without host hardware
  boot.isContainer = true;
  networking.hostName = "studio";
  users.users.river.isNormalUser = true;
  system.stateVersion = "26.05";
}
```

Program supplies the raw Furnish namespace, user authority, managed root, source shape, and declaration label. You do not write `lexicon.furnish.declarations` yourself. `lexicon.furnish.enable` is the host's explicit choice to run the imported runtime; the checkout command below only evaluates its manifest.

```sh
nix eval --impure --json --file examples/program-eval.nix files.file
```

<!-- program-value: files.file -->
```json
{
  "furnishEnabled": true,
  "manifest": [
    {
      "destination": "/home/river/.config/paperkite/settings.conf",
      "onConflict": "error",
      "representation": "symlink"
    }
  ],
  "outputs": ["nixos"],
  "serviceEnabled": true
}
```

Use [files and directories](files.md) for writable files, conflict policies, directory expansion, and path restrictions. Use the raw [Furnish manual](../furnish/README.md) when the task is general file lifecycle management rather than application configuration.

## Use the example as an ordinary flake

Copy the four files from `examples/program-minimal` into an empty project directory. From that new directory, let Nix lock the declared GitHub inputs, evaluate the NixOS-backed result, and build its lightweight checked output without activation:

```sh
nix flake lock
nix eval --json .#lib.result
nix build --no-link .#checks.x86_64-linux.example
```

The first lock operation creates that consumer project's `flake.lock`. The later commands reuse it. After changing the example from `focused` to `quiet` or adding the file-producing capability, run the same evaluation and build commands again. The existing lock keeps the selected input revisions unchanged.

Next, use [common Program capabilities](usage.md) to add packages and Home Manager imports without assuming Furnish.

[Program contents](README.md) · [Common usage](usage.md) · [Examples](../../examples/README.md#program)
