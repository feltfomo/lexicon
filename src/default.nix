# every subsystem takes lib and fx from here. two nix-effects instances make
# types that never compare equal
{ lib, fx }:
{
  inherit lib fx;

  version = "0.0.0";

  # every other subsystem reports through it
  krisis = import ./krisis { inherit lib fx; };
}
