# Worked example: inspect, build, and check

This project gives common Nix work stable names. It evaluates project data, builds one harmless text output, runs the flake checks, and optionally composes inspection and checking.

The complete project is `examples/praxis-project`. `flake.nix` exposes the `praxis` output and imports the declaration from `praxis.nix`, which suits a declaration this long.

<!-- source: ../../examples/praxis-project/flake.nix -->
```nix
{
  description = "A safe Praxis build workflow";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      artifact = pkgs.writeText "praxis-example-result" "built safely\n";
    in
    {
      status = "ready";
      packages.${system}.default = artifact;
      checks.${system}.artifact = pkgs.runCommandLocal "praxis-example-check" { } ''
        grep -F 'built safely' ${artifact}
        touch $out
      '';
      # the same declaration, kept in its own file once it grows
      praxis = import ./praxis.nix;
    };
}
```

<!-- source: ../../examples/praxis-project/praxis.nix -->
```nix
{
  pkgs,
  root,
  ...
}:
{
  atRoot = true;
  commands = {
    inspect = {
      description = "Evaluate the project status";
      command = [
        "nix"
        "eval"
        "--json"
        ".#status"
      ];
    };
    build = {
      description = "Build the supplied harmless output";
      command = [
        "nix"
        "build"
        ".#default"
      ];
    };
    check = {
      description = "Run every project check";
      command = [
        "nix"
        "flake"
        "check"
        "-L"
      ];
    };
  };
  tasks.verify = {
    description = "Inspect and check the project";
    # composition comes after each direct command remains useful alone
    steps = [
      "inspect"
      "check"
    ];
  };
}
```

Run each command directly:

<!-- praxis-command: project.inspect -->
```sh
praxis inspect
```

<!-- praxis-output: project.inspect -->
```text
"ready"
```

<!-- praxis-command: project.build -->
```sh
praxis --quiet build
```

The build creates the ordinary local `result` link for the supplied text output. It does not activate a host.

<!-- praxis-command: project.check -->
```sh
praxis --quiet check
```

The optional task keeps the direct commands reusable:

<!-- praxis-command: project.verify -->
```sh
praxis --quiet verify
```

<!-- praxis-output: project.verify -->
```text
"ready"
```

Continue with the exact [public reference](reference.md).
