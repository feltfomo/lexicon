{
  description = "Standalone TOML and explicit theme composition";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.lexicon.url = "github:feltfomo/lexicon";
  outputs =
    { nixpkgs, lexicon, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      toml = lexicon.lib.toml { inherit pkgs; };
      base = {
        onboarding = false;
        keys.command = [
          {
            key = "prefix+f";
            command = "find-pane";
          }
        ];
      };
      program = lexicon.lib.programDirect {
        target = {
          host = {
            name = "studio";
            inherit system;
          };
          user.name = "river";
        };
      };
      app = program {
        theme = {
          id = "app";
          output = ".config/app/config.toml";
          merge = {
            format = "toml";
            inherit base;
          };
          renderers.noctalia.source = ./palette.toml;
        };
      };
    in
    {
      packages.${system}.default = toml.generate "app.toml" base;
      nixosConfigurations.demo = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          app.nixos
          {
            boot.isContainer = true;
            networking.hostName = "studio";
            users.users.river.isNormalUser = true;
            lexicon.furnish.enable = true;
            system.stateVersion = "26.05";
          }
        ];
      };
    };
}
