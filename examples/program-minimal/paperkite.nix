{ program }:
program {
  # ordinary NixOS options remain opaque to Program's claim validation
  nixos.environment.variables.PAPERKITE_MODE = "focused";
}
