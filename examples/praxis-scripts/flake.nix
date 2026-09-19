{
  description = "Praxis scripts and project roots";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    {
      # the same declaration, kept in its own file once it grows
      praxis = import ./praxis.nix;
    };
}
