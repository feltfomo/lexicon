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
