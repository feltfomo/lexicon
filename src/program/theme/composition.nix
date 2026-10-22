{ lib }:
let
  idOf = output: builtins.substring 0 32 (builtins.hashString "sha256" output);
  descriptorOf = output: ".config/lexicon/toml/${idOf output}.json";
  homeOf =
    principal:
    toString (builtins.toPath (principal.managedRoot or "/home/${principal.authority.identity}"));
  lower =
    pkgs: entry:
    if entry.merge == null then
      entry
    else
      let
        toml = import ../../toml { inherit pkgs lib; };
        home = homeOf entry.principal;
        effectiveReload = if entry.reload != null then entry.reload else entry.native.post_hook or null;
        staging = ".local/state/lexicon/toml/${idOf entry.output}/${entry.renderer}-${entry.registrationId}.toml";
      in
      assert lib.assertMsg (
        effectiveReload == null || builtins.isString effectiveReload
      ) "theme.merge: native.post_hook must be a string or null";
      entry
      // {
        compositionHome = home;
        finalOutput = entry.output;
        originalReload = effectiveReload;
        output = staging;
        reload = "${toml.package}/bin/lexicon-toml publish ${lib.escapeShellArg "${home}/${descriptorOf entry.output}"} --theme ${lib.escapeShellArg "${home}/${staging}"}";
      };
in
{
  inherit
    idOf
    descriptorOf
    lower
    homeOf
    ;
}
