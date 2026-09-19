{ lexicon, nixpkgs }:
let
  example = name: (import (./. + "/${name}/flake.nix")).outputs { inherit lexicon nixpkgs; };
in
{
  minimal = (example "program-minimal").lib;
  capabilities = (example "program-capabilities").lib;
  files = (example "program-files").lib;
  themes = (example "program-themes").lib;
  ownerships = (example "program-ownerships").lib;
  den = (example "program-den").lib;
  studio = (example "program-studio").lib;
}
