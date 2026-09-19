{
  description = "Everyday Nix work with memorable names";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # the host names this configuration builds; the rebuild command binds one of them
      hosts = [
        "workstation"
        "server"
      ];
      packages.${system}.default = pkgs.writeText "praxis-everyday-result" "built safely\n";
      checks.${system}.artifact = pkgs.runCommandLocal "praxis-everyday-check" { } ''
        touch $out
      '';
      # the same declaration, kept in its own file once it grows
      praxis = import ./praxis.nix;
    };
}
