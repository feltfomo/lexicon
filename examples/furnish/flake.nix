{
  description = "Minimal Furnish managed-file example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    lexicon = {
      url = "github:feltfomo/lexicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      lexicon,
      ...
    }:
    let
      host = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          (import ./files.nix { inherit lexicon; })
          {
            # container scaffolding keeps the example buildable without host hardware
            boot.isContainer = true;
            networking.hostName = "studio";
            users.users.river.isNormalUser = true;
            system.stateVersion = "26.05";
          }
        ];
      };
      # keep the first result stable by omitting store paths and integration metadata
      projectEntry = entry: {
        inherit (entry) onConflict representation;
        inherit (entry.filesystemIdentity) destination;
      };
    in
    {
      nixosConfigurations.demo = host;
      lib = {
        manifest = map projectEntry host.config.lexicon.furnish.manifestData;
        runtime = {
          enabled = host.config.lexicon.furnish.enable;
          ledgerPath = host.config.lexicon.furnish.ledgerPath;
          manifestAvailable = host.config.lexicon.furnish.manifestPath != null;
          serviceEnabled = host.config.systemd.services ? furnish;
        };
      };
    };
}
