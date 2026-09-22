# the interior names a module where a module belongs
{ entry, ... }:
entry {
  nixos = "./system-configuration.nix";
}
