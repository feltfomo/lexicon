{
  description = "Focused Furnish representation and conflict-policy examples";

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
      # keep review output independent of retained store paths
      projectEntry = entry: {
        inherit (entry)
          authority
          onConflict
          provenance
          representation
          ;
        inherit (entry.filesystemIdentity) canonical destination namespace;
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
