{ lib }:
# Validation and Matugen collection share this backend catalog. Each adapter
# supplies its capabilities and registration paths for the principal's home.
{
  caelestia = import ./caelestia.nix { inherit lib; };
  dms = import ./dms.nix { inherit lib; };
  end4-pc = import ./end4-pc.nix { inherit lib; };
  illogical-impulse = import ./illogical-impulse.nix { inherit lib; };
  lucid = import ./lucid.nix { inherit lib; };
  noctalia = import ./noctalia.nix { inherit lib; };
  serpantinum = import ./serpantinum.nix { inherit lib; };
}
