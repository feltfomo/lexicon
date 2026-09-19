{ lexicon, nixpkgs }:
let
  example = name: (import (./. + "/${name}/flake.nix")).outputs { inherit lexicon nixpkgs; };
in
{
  minimal = (example "furnish").lib;
  policies = (example "furnish-policies").lib;
  studio = (example "furnish-studio").lib;
}
