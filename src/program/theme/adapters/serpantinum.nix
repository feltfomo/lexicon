{ lib }:
let
  capability = import ../capabilities.nix;
in
{
  # Serpantinum selects this config explicitly; DMS owns Matugen's default.
  capabilities = [
    capability.nativeBlocks
    capability.matugenRuntime
  ];
  runtime = "matugen";
  configDestination = ".config/serpantinum/matugen/config.toml";
  templateRoot = ".config/serpantinum/matugen/templates";
  templateNameOf = entry: "${entry.subdir}${entry.placedAs}";
  filesFor = _: [ ];
  registrationOf =
    entry:
    let
      home = lib.removeSuffix "/" (
        entry.principal.managedRoot or "/home/${entry.principal.authority.identity}"
      );
    in
    entry.native
    // {
      input_path = "${home}/.config/serpantinum/matugen/templates/${entry.subdir}${entry.placedAs}";
      output_path = "${home}/${entry.output}";
    }
    // lib.optionalAttrs (entry.reload != null) { post_hook = entry.reload; };
}
