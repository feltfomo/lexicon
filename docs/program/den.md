# Bind Program to Den

Den is an optional external configuration framework. It is not needed for `programDirect`, for Program's declaration vocabulary, or for file publication.

Use `programDen` when an existing Den setup should provide the fleet roster, selected user principal, and host-user inventory through Lexicon's Den adapter boundary.

## The one required wiring step

`programDen` takes the `den` value your Den flake exposes and returns the ordinary `program { ... }` declaration function. It reads only Den's public host surface: `den.hosts.<system>.<host>`, each host's `dimensions`, and its `users`. It forces neither `den.lib` nor host instantiation.

This is the complete adaptable skeleton. Put it in the file where your framework already evaluates application modules, and where `den` and your flake `inputs` are in scope as arguments:

```nix
# e.g. modules/paperkite.nix in your own configuration, imported by the module
# graph you already use
{ den, inputs, ... }:
let
  program = inputs.lexicon.lib.programDen { inherit den; };
in
program {
  users = [ "river" ];
  packages = [ ];
  files = [
    {
      dest = ".config/paperkite/den.conf";
      src = ./settings.conf;
    }
  ];
}
```

What each part is:

- `inputs.lexicon` is the Lexicon flake input you add to your own flake; nothing else is required from Lexicon.
- `den` is the value your Den flake exposes. Supply it as a module argument in whatever layout your configuration already uses, or pass it explicitly when you import the file. Lexicon does not discover it, and no particular filename is involved.
- `programDen { inherit den; }` returns the `program` declaration function. Call it once and reuse the result for every application file.
- `program { ... }` returns a record of output projections, such as `nixos`, which you place into the module graph you already evaluate.

If your Den setup evaluates through flake-parts and receives `den` as a flake-parts module argument, call `programDen` in that module and pass the resulting declaration onward as an ordinary module argument. That wiring belongs to your framework; Program itself requires no flake-parts wiring and no additional file convention.

## The checked example, file by file

`examples/program-den` is the same shape split across small files so each binding is visible.

`program-binding.nix` performs the single adapter call:

<!-- source: ../../examples/program-den/program-binding.nix -->
```nix
{ lexicon, den }:
# one constructor call is the whole Den binding; the roster, selected principal,
# and host-user inventory come from den's public value
lexicon.lib.programDen { inherit den; }
```

`paperkite.nix` holds the application declaration and stays free of adapter internals:

<!-- source: ../../examples/program-den/paperkite.nix -->
```nix
{ program }:
program {
  # a claim names which roster principals receive this declaration
  users = [ "river" ];
  files = [
    {
      dest = ".config/paperkite/den.conf";
      src = ./settings.conf;
    }
  ];
}
```

Claims such as `users` work because `programDen` derives the public roster from `den` and delegates to the Ownerships-backed binding. Complete claim semantics remain in the [Ownerships manual](../ownerships/README.md).

`configuration.nix` imports the NixOS projection the declaration produced and turns on the Furnish runtime:

<!-- source: ../../examples/program-den/configuration.nix -->
```nix
{ paperkite }:
{
  imports = [ paperkite.nixos ];
  lexicon.furnish.enable = true;
  # container scaffolding keeps the example buildable without host hardware
  boot.isContainer = true;
  networking.hostName = "studio";
  users.users.river.isNormalUser = true;
  system.stateVersion = "26.05";
}
```

`flake.nix` ties those files together and builds the host. The selected host and user reach Program through the module arguments the configuration is evaluated with:

<!-- excerpt: ../../examples/program-den/flake.nix -->
```nix
      den = import ./den-fixture.nix { inherit system; };
      program = import ./program-binding.nix { inherit lexicon den; };
      paperkite = import ./paperkite.nix { inherit program; };
      demo = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          host = {
            id = "${system}/studio";
            name = "studio";
            inherit system;
          };
          user = {
            name = "river";
            home = "/home/river";
          };
        };
        modules = [ (import ./configuration.nix { inherit paperkite; }) ];
      };
```

Verify the binding from the Lexicon repository root:

```sh
nix eval --impure --json --file examples/program-eval.nix den.result
```

<!-- program-value: den.result -->
```json
{
  "authority": {
    "identity": "river",
    "scope": "user"
  },
  "destination": "/home/river/.config/paperkite/den.conf",
  "entryCount": 1,
  "outputs": ["nixos"]
}
```

Successful output proves the adapter produced a real Program result: the one selected user yielded one user-authority file declaration, the target namespace is the canonical Den host ID, and the managed root is that user's home.

## The repository's test stand-in

So the checked example evaluates without adding Den as an input, `examples/program-den/den-fixture.nix` supplies only the public host surface the adapter reads, with throwing placeholders for everything it must never force. That file is a boundary test, not part of the recipe above:

<!-- source: ../../examples/program-den/den-fixture.nix -->
```nix
{ system }:
# this fixture proves the adapter boundary without instantiating a Den host
{
  hosts.${system}.studio = {
    dimensions = { };
    users.river = { };
    aspect = throw "the Program Den example forced host aspect internals";
    instantiate = throw "the Program Den example forced host instantiation";
  };
  lib = throw "the Program Den example forced den.lib";
}
```

## A real-world reference

I use Program with Den in my own NixOS configuration, [Skadi](https://github.com/feltfomo/skadi), if you would like to see a full setup rather than an example.

For the adapter contract and custom alternatives, continue to the [advanced binding reference](advanced-reference.md).

[Program contents](README.md) · [Ownerships integration](ownerships.md) · [Advanced binding](advanced-reference.md)
