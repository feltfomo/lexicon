{
  description = "A coherent direct Program editor configuration";
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
      inherit (pkgs) lib;
      program = import ./program-binding.nix { inherit lexicon system; };
      helix = import ./helix.nix { inherit program; };
      homeOptions =
        { lib, ... }:
        {
          options.home = {
            username = lib.mkOption { type = lib.types.str; };
            homeDirectory = lib.mkOption { type = lib.types.str; };
            stateVersion = lib.mkOption { type = lib.types.str; };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
            };
            sessionVariables = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
            };
          };
        };
      homeModules = lib.evalModules {
        specialArgs = { inherit helix pkgs; };
        modules = [
          homeOptions
          ./home.nix
        ];
      };
      home = homeModules.config.home;
      demo = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ (import ./configuration.nix { inherit helix; }) ];
      };
      destinations = builtins.sort builtins.lessThan (
        map (entry: entry.filesystemIdentity.destination) demo.config.lexicon.furnish.manifestData
      );
    in
    {
      nixosConfigurations.demo = demo;
      checks.${system}.example = pkgs.runCommandLocal "program-studio-example" { } (
        assert
          builtins.attrNames helix == [
            "homeManager"
            "nixos"
          ];
        assert builtins.length destinations == 3;
        assert home.username == "river";
        assert home.homeDirectory == "/home/river";
        assert home.stateVersion == "26.05";
        assert map (package: package.pname) home.packages == [ "helix" ];
        assert home.sessionVariables.EDITOR == "hx";
        "touch $out"
      );
      # these values exist for the documentation tests, not for a real configuration
      lib.result = {
        outputs = builtins.attrNames helix;
        package = (builtins.head home.packages).pname;
        editor = home.sessionVariables.EDITOR;
        homeUser = home.username;
        inherit (home) homeDirectory;
        homeStateVersion = home.stateVersion;
        nixosEditor = demo.config.environment.variables.EDITOR;
        inherit destinations;
      };
    };
}
