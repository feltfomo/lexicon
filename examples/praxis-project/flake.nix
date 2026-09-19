{
  description = "A safe Praxis build workflow";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      artifact = pkgs.writeText "praxis-example-result" "built safely\n";
    in
    {
      status = "ready";
      packages.${system}.default = artifact;
      checks.${system}.artifact = pkgs.runCommandLocal "praxis-example-check" { } ''
        grep -F 'built safely' ${artifact}
        touch $out
      '';
      # the same declaration, kept in its own file once it grows
      praxis = import ./praxis.nix;
    };
}
