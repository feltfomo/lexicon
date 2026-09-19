{
  description = "Registry, Ownerships, Program, Furnish and Praxis in one NixOS setup";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.lexicon.url = "github:feltfomo/lexicon";
  inputs.home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      nixpkgs,
      lexicon,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      setup = import ./setup.nix { inherit lexicon pkgs; };
    in
    setup.tasks.flake
    // {
      nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          home-manager.nixosModules.home-manager
          (import ./configuration.nix { inherit setup; })
        ];
      };
    };
}
