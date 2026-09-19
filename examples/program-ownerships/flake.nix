{
  description = "Optional Ownerships-backed Program selection";
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
      ownerships = lexicon.lib.ownerships { };
      roster = import ./roster.nix { inherit ownerships system; };
      program = import ./program-binding.nix { inherit lexicon roster; };
      editor = import ./editor.nix { inherit program; };
      host = {
        id = "${system}/studio";
        name = "studio";
        inherit system;
      };
      userFor = name: {
        inherit name;
        home = "/home/${name}";
      };
      homeImportsFor =
        name:
        (editor.homeManager {
          inherit lib pkgs host;
          user = userFor name;
        }).imports;
      systemFor =
        name:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit host;
            user = userFor name;
          };
          modules = [
            editor.nixos
            {
              # container scaffolding keeps the example buildable without host hardware
              boot.isContainer = true;
              networking.hostName = "studio";
              users.users.${name}.isNormalUser = true;
              lexicon.furnish.enable = true;
              system.stateVersion = "26.05";
            }
          ];
        };
      alice = systemFor "alice";
      bob = systemFor "bob";
      editorFor =
        name:
        let
          imports = homeImportsFor name;
        in
        if imports == [ ] then null else (builtins.head imports).home.sessionVariables.EDITOR;
      destinations =
        systemConfig:
        map (entry: entry.filesystemIdentity.destination) systemConfig.config.lexicon.furnish.manifestData;
    in
    {
      nixosConfigurations = { inherit alice bob; };
      # these values exist for the documentation tests, not for a real configuration
      lib.result = {
        outputs = builtins.attrNames editor;
        alice = {
          editor = editorFor "alice";
          files = destinations alice;
        };
        bob = {
          editor = editorFor "bob";
          files = destinations bob;
        };
      };
    };
}
