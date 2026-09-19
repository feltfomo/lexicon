# Install Praxis and run your first project command

Praxis is one generic Linux command, `praxis`, published as `packages.<system>.praxis`. Put it in a package list once; every project you later declare is reached by that same command.

## Put the package in your configuration

Add Lexicon as a flake input and add its `praxis` package to the package list your machine already builds. The complete file below is `examples/praxis-install/flake.nix`; in your own setup it is the flake that builds your machine, such as `/etc/nixos/flake.nix`.

<!-- source: ../../examples/praxis-install/flake.nix -->
```nix
{
  description = "Declarative placement of the generic Praxis package";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    { nixpkgs, ... }@inputs:
    {
      # the machine configuration you already build; praxis joins its package list
      nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # the module below reads inputs, so the evaluation has to supply them
        specialArgs = { inherit inputs; };
        modules = [
          (
            { inputs, pkgs, ... }:
            {
              environment.systemPackages = [ inputs.lexicon.packages.${pkgs.system}.praxis ];
              networking.hostName = "workstation";
              system.stateVersion = "26.05";
            }
          )
        ];
      };
    };
}
```

The module receives `inputs` through `specialArgs` and `pkgs` from the module system, which is what makes `inputs.lexicon.packages.${pkgs.system}.praxis` resolve inside it. Switch the configuration the way you normally do, from the directory holding that flake:

```sh
sudo nixos-rebuild switch --flake .#workstation
```

If you manage your user environment with Home Manager, use this module instead of the NixOS block above. The complete file is `examples/praxis-install/home.nix`:

<!-- source: ../../examples/praxis-install/home.nix -->
```nix
# a Home Manager module for the same package; import it from your Home Manager
# configuration, which must pass the flake inputs through
# extraSpecialArgs = { inherit inputs; }
{
  inputs,
  pkgs,
  ...
}:
{
  home.packages = [ inputs.lexicon.packages.${pkgs.system}.praxis ];
}
```

Import it from your Home Manager configuration and switch that configuration normally. One placement is enough; Praxis does not require Home Manager.

After the switch, the command is on `PATH` in any directory:

<!-- praxis-command: getting.version -->
```sh
praxis --version
```

<!-- praxis-output: getting.version -->
```text
praxis 1.0.0
```

## Expose a declaration from `flake.nix`

A Praxis project is one ordinary flake. `flake.nix` exposes a `praxis` output, and the installed command runs what that output declares. Create a separate directory containing this complete `flake.nix`, then run the remaining commands from that directory or a subdirectory of it.

<!-- source: ../../examples/praxis-minimal/flake.nix -->
```nix
{
  description = "A first installed Praxis project";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }: {
    status = "ready";
    detailedStatus = "ready for checks";

    # the installed dispatcher runs the commands this output declares
    praxis =
      { pkgs, root, ... }:
      {
        atRoot = true;
        # the first command evaluates project data without changing the system
        commands.inspect = [
          "nix"
          "eval"
          "--json"
          ".#status"
        ];
      };
  };
}
```

The `praxis` output is a function receiving `pkgs`, the project's package set for the current system, and `root`, the flake's source root. `flake.nix` must declare `inputs.nixpkgs`. The project publishes no Praxis package or app.

Create the project's initial lock before running the declared `nix` command, because `praxis` never writes it for you:

```sh
nix flake lock
```

Run the command from the project directory:

<!-- praxis-command: getting.inspect -->
```sh
praxis inspect
```

<!-- praxis-output: getting.inspect -->
```text
"ready"
```

## Make one meaningful edit

In the project's `flake.nix`, change `".#status"` to `".#detailedStatus"` and run the same command again. Reinstalling Praxis is unnecessary, because the declaration is reevaluated on every invocation.

<!-- praxis-command: getting.edited -->
```sh
praxis inspect
```

<!-- praxis-output: getting.edited -->
```text
"ready for checks"
```

## Move the same declaration into another file

Once a declaration grows past a few commands, keep it in its own file and import it, as `examples/praxis-commands` does:

<!-- excerpt: ../../examples/praxis-commands/flake.nix -->
```nix
      # the same declaration, kept in its own file once it grows
      praxis = import ./praxis.nix;
```

The imported file holds exactly the same function the inline declaration held, so the commands and their results are unchanged. The file may be named anything and may live in a subdirectory; `praxis` reads the flake output, never a filename.

If the nearest `flake.nix` above your working directory exposes no `praxis` output, the command names that project and stops rather than searching further up.

## Optional: availability inside one project

If you would rather reach `praxis` only inside a particular project, add the same generic package to that project's development shell, as `examples/praxis-shell` does:

<!-- excerpt: ../../examples/praxis-shell/flake.nix -->
```nix
      # the same generic package, reachable only while this shell is entered
      devShells.${system}.default = pkgs.mkShell {
        packages = [ lexicon.packages.${system}.praxis ];
      };
```

Enter the shell with `nix develop` and the direct commands work as shown above; leaving it removes that project-local availability. The declaration contract is identical either way.

Next, give [your everyday Nix work names](everyday-commands.md): a rebuild for each host, an update, and a check.
