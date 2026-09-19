{
  description = "Program bound to Den's public roster";
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
      # a real project passes the den value its Den flake exposes; this example
      # substitutes a deterministic stand-in so it evaluates with no extra input
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
      manifest = demo.config.lexicon.furnish.manifestData;
    in
    {
      nixosConfigurations.demo = demo;
      # these values exist for the documentation tests, not for a real configuration
      lib.result = {
        outputs = builtins.attrNames paperkite;
        entryCount = builtins.length manifest;
        destination = (builtins.head manifest).filesystemIdentity.destination;
        inherit ((builtins.head manifest)) authority;
      };
    };
}
