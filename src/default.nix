# every subsystem takes lib and fx from here. two nix-effects instances make
# types that never compare equal
{ lib, fx }:
{
  inherit lib fx;

  version = "0.0.0";
}
