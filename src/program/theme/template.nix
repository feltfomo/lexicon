{ lib }:
let
  material = [
    "background"
    "error"
    "errorContainer"
    "inverseOnSurface"
    "inversePrimary"
    "inverseSurface"
    "onBackground"
    "onError"
    "onErrorContainer"
    "onPrimary"
    "onPrimaryContainer"
    "onPrimaryFixed"
    "onPrimaryFixedVariant"
    "onSecondary"
    "onSecondaryContainer"
    "onSecondaryFixed"
    "onSecondaryFixedVariant"
    "onSurface"
    "onSurfaceVariant"
    "onTertiary"
    "onTertiaryContainer"
    "onTertiaryFixed"
    "onTertiaryFixedVariant"
    "outline"
    "outlineVariant"
    "primary"
    "primaryContainer"
    "primaryFixed"
    "primaryFixedDim"
    "scrim"
    "secondary"
    "secondaryContainer"
    "secondaryFixed"
    "secondaryFixedDim"
    "shadow"
    "surface"
    "surfaceBright"
    "surfaceContainer"
    "surfaceContainerHigh"
    "surfaceContainerHighest"
    "surfaceContainerLow"
    "surfaceContainerLowest"
    "surfaceDim"
    "surfaceTint"
    "surfaceVariant"
    "tertiary"
    "tertiaryContainer"
    "tertiaryFixed"
    "tertiaryFixedDim"
  ];
  terminal = map (index: "term${toString index}") (lib.range 0 15);
  tokens =
    material
    ++ terminal
    ++ [
      "success"
      "warning"
    ];
  tokenIndex = lib.genAttrs tokens (_: true);

  modes = [
    "dark"
    "light"
  ];
  modifiers = modes ++ [ "bare" ];

  placeholderOf =
    text:
    let
      segments = map lib.trim (lib.splitString "|" text);
      path = lib.splitString "." (builtins.head segments);
    in
    {
      text = "{{${text}}}";
      name = builtins.head path;
      modifiers = builtins.tail path;
      modes = builtins.filter (modifier: builtins.elem modifier modes) (builtins.tail path);
      bare = builtins.elem "bare" (builtins.tail path);
      filters = builtins.tail segments;
    };

  # placeholders are matched without nesting so a brace pair inside a template's own
  # syntax, such as a css rule, stays literal text
  parse =
    text:
    map (
      fragment: if builtins.isString fragment then fragment else placeholderOf (builtins.head fragment)
    ) (builtins.split "\\{\\{([^{}]*)}}" text);

  issuesOf =
    placeholder:
    lib.optional (!(tokenIndex ? ${placeholder.name})) {
      tag = "unknown-token";
      inherit (placeholder) name text;
    }
    ++ map (modifier: {
      tag = "unknown-modifier";
      inherit modifier;
      inherit (placeholder) text;
    }) (builtins.filter (modifier: !(builtins.elem modifier modifiers)) placeholder.modifiers)
    ++ lib.optional (builtins.length placeholder.modes > 1) {
      tag = "conflicting-modes";
      inherit (placeholder) text;
    };
in
{
  inherit parse modifiers tokens;

  issues = fragments: builtins.concatMap issuesOf (builtins.filter builtins.isAttrs fragments);

  # the fragments must be free of issues, because a dialect only covers known tokens
  render =
    dialect: fragments:
    lib.concatStrings (
      map (fragment: if builtins.isString fragment then fragment else dialect fragment) fragments
    );
}
