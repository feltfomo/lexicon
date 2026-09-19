{ lexicon, nixpkgs }:
let
  example = name: (import (./. + "/${name}/flake.nix")).outputs { inherit lexicon nixpkgs; };
in
{
  minimal = (example "ownerships-minimal").lib;
  preferences = (example "ownerships").lib;
  claims = (example "ownerships-claims").lib;
  merge = (example "ownerships-merge").lib;
  files = (example "ownerships-files").lib;
  team = (example "ownerships-team").lib;
}
