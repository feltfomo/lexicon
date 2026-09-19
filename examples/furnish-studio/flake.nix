{
  description = "Larger Furnish-only Paperkite studio example";

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
        # pass the pinned Lexicon input through the NixOS module graph
        specialArgs = { inherit lexicon; };
        modules = [ ./configuration.nix ];
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
      nixosConfigurations.studio = host;
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
