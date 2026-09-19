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
  wrappers ? false,
}:
let
  file = pkgs.writeText "praxis-${name}.json" (builtins.toJSON manifest);
  selection = lib.optionalString (command != null) "run ${lib.escapeShellArg command}";
  launcher = pkgs.writeShellApplication {
    inherit name;
    meta = {
      inherit description;
      mainProgram = name;
    };
    text = ''
      exec ${runner}/bin/praxis --manifest ${file} ${selection} "$@"
    '';
  };
in
if command != null then
  launcher
else
  pkgs.symlinkJoin {
    inherit name;
    inherit (launcher) meta;
    paths = [ launcher ];
    # native command completions stay untouched unless wrappers were requested
    postBuild = ''
      mkdir -p "$out/share/fish/vendor_completions.d" \
        "$out/share/bash-completion/completions" "$out/share/zsh/site-functions"
      ${runner}/bin/praxis --manifest ${file} completions fish ${lib.optionalString wrappers "--wrappers"} > "$out/share/fish/vendor_completions.d/${name}.fish"
      ${runner}/bin/praxis --manifest ${file} completions bash ${lib.optionalString wrappers "--wrappers"} > "$out/share/bash-completion/completions/${name}"
      ${runner}/bin/praxis --manifest ${file} completions zsh ${lib.optionalString wrappers "--wrappers"} > "$out/share/zsh/site-functions/_${name}"
    '';
  }
