{
  description = "Program files and directory expansion";
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
      program = import ./program-binding.nix { inherit lexicon system; };
      fileOnly = import ./files.nix { inherit program; };
      directoryOnly = import ./directory.nix { inherit program; };
      systemFor =
        declaration:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ (import ./configuration.nix { inherit declaration; }) ];
        };
      fileSystem = systemFor fileOnly;
      directorySystem = systemFor directoryOnly;
      project = entry: {
        destination = entry.filesystemIdentity.destination;
        inherit (entry) onConflict representation;
      };
      ordered =
        entries: builtins.sort (left: right: left.destination < right.destination) (map project entries);
    in
    {
      nixosConfigurations = {
        file = fileSystem;
        directory = directorySystem;
      };
      # these values exist for the documentation tests, not for a real configuration
      lib = {
        file = {
          outputs = builtins.attrNames fileOnly;
          furnishEnabled = fileSystem.config.lexicon.furnish.enable;
          serviceEnabled = fileSystem.config.systemd.services ? furnish;
          manifest = ordered fileSystem.config.lexicon.furnish.manifestData;
        };
        directory = {
          outputs = builtins.attrNames directoryOnly;
          manifest = ordered directorySystem.config.lexicon.furnish.manifestData;
        };
      };
    };
}
