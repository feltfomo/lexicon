{
  description = "A file-producing Program theme";
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
      program = lexicon.lib.programDirect {
        target = {
          host = {
            name = "studio";
            inherit system;
          };
          user.name = "river";
        };
      };
      theme = import ./theme.nix { inherit program; };
      demo = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ (import ./configuration.nix { inherit theme; }) ];
      };
      destinations = builtins.sort builtins.lessThan (
        map (entry: entry.filesystemIdentity.destination) demo.config.lexicon.furnish.manifestData
      );
    in
    {
      nixosConfigurations.demo = demo;
      # these values exist for the documentation tests, not for a real configuration
      lib.result = {
        outputs = builtins.attrNames theme;
        inherit destinations;
        furnishEnabled = demo.config.lexicon.furnish.enable;
      };
    };
}
