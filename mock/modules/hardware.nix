# the disks and the bootloader. the machine's hardware field selects one
# block of settings out of the set, and every block is written out in full
{ entry, ... }:
entry {
  nixos =
    { lib, host, ... }:
    {
      config = lib.mkMerge (
        lib.mapAttrsToList (name: held: lib.mkIf (host.hardware == name) held) (
          import ../_boilerplate/hardware.nix
        )
      );
    };
}
