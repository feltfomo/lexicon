{
  description = "Praxis output choices";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    { nixpkgs, lexicon, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # this focused flake enables each output switch for comparison
      published = lexicon.lib.praxis {
        inherit pkgs;
        name = "work";
        commands.unit = [ "${pkgs.coreutils}/bin/true" ];
        check = true;
        checks = [ "unit" ];
        devShell = true;
        perCommand = true;
        wrappers = true;
      };
    in
    published.flake;
}
