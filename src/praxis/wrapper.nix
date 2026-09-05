{
  lib,
  pkgs,
  runner,
}:
{
  name,
  manifest,
  command,
  description,
}:
let
  file = pkgs.writeText "praxis-${name}.json" (builtins.toJSON manifest);
  selection = lib.optionalString (command != null) "run ${lib.escapeShellArg command}";
in
pkgs.writeShellApplication {
  inherit name;
  meta = {
    inherit description;
    mainProgram = name;
  };
  text = ''
    exec ${runner}/bin/praxis --manifest ${file} ${selection} "$@"
  '';
}
