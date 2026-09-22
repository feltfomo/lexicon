# a rendered palette and the hook that reloads whatever consumed it. the shape
# is the one the fleet configuration on this machine writes, read 2026-09-20
# out of hyprland.nix, qt-hm.nix, ghostty.nix, nvim.nix and mangowm.nix. what a
# renderer does with the artifact lives in an external flake this tree cannot
# read, so nothing downstream of source is checked
{
  lib,
  fx,
  suggest,
  shown,
  prose,
  ...
}:
let
  topKeys = [
    "id"
    "output"
    "placedAs"
    "reload"
    "renderers"
    "templates"
  ];

  templateKeys = [
    "subId"
    "output"
    "placedAs"
    "reload"
    "renderers"
  ];

  rendererKeys = [
    "source"
    "output"
    "placedAs"
    "reload"
    "sharedWith"
  ];

  strings = value: builtins.isList value && builtins.all builtins.isString value;

  unknown =
    emit: at: allowed: value:
    map (
      field:
      let
        nearest = suggest field allowed;
      in
      emit.theme-unknown-field {
        at = at ++ [ field ];
        context = {
          inherit field;
        };
        notes = lib.optional (nearest != null) "did you mean '${nearest}'?";
      }
    ) (builtins.filter (field: !builtins.elem field allowed) (builtins.attrNames value));

  malformed =
    emit: at: field: expected:
    emit.theme-malformed-field {
      at = at ++ [ field ];
      context = {
        inherit field expected;
      };
    };

  optionalString =
    emit: at: value: field:
    lib.optional (value ? ${field} && !builtins.isString value.${field}) (
      malformed emit at field "a string"
    );

  renderer =
    emit: at: value:
    if !builtins.isAttrs value then
      [ (malformed emit at "source" "a renderer with a source") ]
    else
      unknown emit at rendererKeys value
      ++ lib.optional (!builtins.isString (value.source or null)) (
        malformed emit at "source" "the template this renderer reads"
      )
      ++ lib.concatMap (optionalString emit at value) [
        "output"
        "placedAs"
        "reload"
      ]
      ++ lib.optional (value ? sharedWith && !strings value.sharedWith) (
        malformed emit at "sharedWith" "a list of renderer names"
      );

  renderers =
    emit: at: value:
    if !(value ? renderers) then
      [ (malformed emit at "renderers" "at least one renderer") ]
    else if !builtins.isAttrs value.renderers then
      [ (malformed emit at "renderers" "an attrset keyed by renderer name") ]
    else
      lib.concatLists (
        lib.mapAttrsToList (
          name: held:
          renderer emit (
            at
            ++ [
              "renderers"
              name
            ]
          ) held
        ) value.renderers
      );

  template =
    emit: at: value:
    if !builtins.isAttrs value then
      [ (malformed emit at "subId" "a template with a subId") ]
    else
      unknown emit at templateKeys value
      ++ lib.optional (!builtins.isString (value.subId or null)) (
        malformed emit at "subId" "a name unique within this theme"
      )
      ++ lib.concatMap (optionalString emit at value) [
        "output"
        "placedAs"
        "reload"
      ]
      ++ renderers emit at value;
in
{
  name = "theme";

  kinds = [
    "entry"
    "home"
  ];

  # the artifact a renderer writes is placed by the block below, so this one
  # is resolved first
  before = [ "furnish" ];

  claimable = [ ];

  codes = {
    theme-unknown-field = {
      message = args: "a theme has no field ${shown args "field"} at this position";
      help = "a theme takes id, output, placedAs, reload and either renderers or templates";
    };

    theme-malformed-field = {
      message = args: "${shown args "field"} must be ${prose args "expected"}";
    };
  };

  validate =
    { emit, value }:
    if !builtins.isAttrs value then
      emit.theme-malformed-field {
        context = {
          field = "theme";
          expected = "an attrset carrying an id";
        };
      }
    else
      fx.seq (
        unknown emit [ ] topKeys value
        ++ lib.optional (!builtins.isString (value.id or null)) (
          malformed emit [ ] "id" "a name unique across the fleet"
        )
        ++ lib.concatMap (optionalString emit [ ] value) [
          "output"
          "placedAs"
          "reload"
        ]
        ++ (
          if !(value ? templates) then
            renderers emit [ ] value
          else if !builtins.isList value.templates then
            [ (malformed emit [ ] "templates" "a list of templates") ]
          else
            lib.concatLists (
              lib.imap0 (
                index: held:
                template emit [
                  "templates"
                  index
                ] held
              ) value.templates
            )
        )
      );

  compile = {
    # one theme with a renderers attrset and one with a templates list reach
    # the same list here, so nothing downstream carries both spellings
    independent =
      value:
      let
        common = builtins.removeAttrs value [
          "id"
          "templates"
          "renderers"
        ];
      in
      {
        id = value.id or null;
        templates =
          if value ? templates then
            map (held: common // held) value.templates
          else
            [ (common // { inherit (value) renderers; }) ];
      };
    dependent = _: compiled: compiled;
  };
}
