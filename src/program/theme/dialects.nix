{ lib }:
let
  uppercase = lib.stringToCharacters "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  lowercase = lib.stringToCharacters "abcdefghijklmnopqrstuvwxyz";
  snakeCase = builtins.replaceStrings uppercase (map (letter: "_${letter}") lowercase);

  color = name: {
    inherit name;
    filters = [ ];
  };

  # matugen has no terminal palette, so these keep sixteen distinct material roles.
  # success and warning are shifted from primary because no material role is green or amber.
  matugenAliases =
    lib.mapAttrs (_: color) {
      term0 = "surface";
      term1 = "error";
      term2 = "primary";
      term3 = "tertiary";
      term4 = "secondary";
      term5 = "inversePrimary";
      term6 = "onTertiaryContainer";
      term7 = "onSurface";
      term8 = "onSurfaceVariant";
      term9 = "errorContainer";
      term10 = "primaryContainer";
      term11 = "tertiaryContainer";
      term12 = "secondaryContainer";
      term13 = "onPrimaryContainer";
      term14 = "onTertiary";
      term15 = "surfaceBright";
    }
    // {
      success = {
        name = "primary";
        filters = [
          "set_hue: 145"
          "set_saturation: 45"
        ];
      };
      warning = {
        name = "primary";
        filters = [
          "set_hue: 45"
          "set_saturation: 60"
        ];
      };
    };

  caelestiaAliases = {
    success = "term2";
    warning = "term3";
  };
in
{
  matugen =
    placeholder:
    let
      resolved = matugenAliases.${placeholder.name} or (color placeholder.name);
      mode = if placeholder.modes == [ ] then "default" else builtins.head placeholder.modes;
      form = if placeholder.bare then "hex_stripped" else "hex";
      filters = lib.concatMapStrings (filter: " | ${filter}") (resolved.filters ++ placeholder.filters);
    in
    "{{ colors.${snakeCase resolved.name}.${mode}.${form}${filters} }}";

  # caelestia generates one active scheme and has no filter stage, so modes and filters
  # resolve to the active color. its hex form never carries a hash.
  caelestia =
    placeholder:
    "${lib.optionalString (!placeholder.bare) "#"}{{ ${
      caelestiaAliases.${placeholder.name} or placeholder.name
    }.hex }}";
}
