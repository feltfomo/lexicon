{ lib }:
let
  capability = import ../capabilities.nix;
in
{
  # Lucid's wallpaper hook selects this config explicitly. DMS owns Matugen's
  # default config, so the two shells must not publish to the same destination.
  capabilities = [
    capability.nativeBlocks
    capability.matugenRuntime
  ];
  runtime = "matugen";
  configDestination = ".config/lucid/matugen/config.toml";
  templateRoot = ".config/lucid/matugen/templates";
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
      input_path = "${home}/.config/lucid/matugen/templates/${entry.subdir}${entry.placedAs}";
      output_path = "${home}/${entry.output}";
    }
    // lib.optionalAttrs (entry.reload != null) { post_hook = entry.reload; };
}
