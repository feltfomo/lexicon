{
  description = "Praxis commands and tasks";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      status = "ready";
      checks.${system}.unit = pkgs.runCommandLocal "praxis-command-example" { } "touch $out";
      # the same declaration, kept in its own file once it grows
      praxis = import ./praxis.nix;
    };
}
