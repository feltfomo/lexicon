# file placement. the field names are the ones the fleet configuration on this
# machine actually writes, read 2026-09-20 out of mangowm.nix, hyprland.nix,
# ghostty.nix and noctalia.nix
{
  lib,
  fx,
  suggest,
  claimKeys,
  shown,
  prose,
  ...
}:
let
  topKeys = [
    "files"
    "directories"
  ]
  ++ claimKeys;

  fileKeys = [
    "src"
    "dest"
  ];

  directoryKeys = [
    "src"
    "dest"
    "exclude"
    "files"
  ];

  memberKeys = [
    "names"
  ]
  ++ claimKeys;

  strings = value: builtins.isList value && builtins.all builtins.isString value;

  unknown =
    emit: at: allowed: value:
    map (
      field:
      let
        nearest = suggest field allowed;
      in
      emit.furnish-unknown-field {
        at = at ++ [ field ];
        context = {
          inherit field;
        };
        notes = lib.optional (nearest != null) "did you mean '${nearest}'?";
      }
    ) (builtins.filter (field: !builtins.elem field allowed) (builtins.attrNames value));

  malformed =
    emit: at: field: expected:
    emit.furnish-malformed-field {
      at = at ++ [ field ];
      context = {
        inherit field expected;
      };
    };

  # a placement without a destination places nothing, so dest is the one field
  # a member cannot leave out
  placement =
    emit: at: allowed: value:
    if !builtins.isAttrs value then
      [ (malformed emit at "dest" "a placement with a destination") ]
    else
      unknown emit at allowed value
      ++ lib.optional (!builtins.isString (value.dest or null)) (
        malformed emit at "dest" "a path under the home directory"
      )
      ++ lib.optional (value ? src && !builtins.isString value.src) (
        malformed emit at "src" "a path or a store path"
      );

  member =
    emit: at: value:
    if !builtins.isAttrs value then
      [ (malformed emit at "names" "a list of file names") ]
    else
      unknown emit at memberKeys value
      ++ lib.optional (!strings (value.names or null)) (malformed emit at "names" "a list of file names");

  directory =
    emit: at: value:
    placement emit at directoryKeys value
    ++ lib.optionals (builtins.isAttrs value) (
      lib.optional (value ? exclude && !strings value.exclude) (
        malformed emit at "exclude" "a list of file names"
      )
      ++ (
        if !(value ? files) then
          [ ]
        else if !builtins.isList value.files then
          [ (malformed emit at "files" "a list of file groups") ]
        else
          lib.concatLists (
            lib.imap0 (
              index: entry:
              member emit (
                at
                ++ [
                  "files"
                  index
                ]
              ) entry
            ) value.files
          )
      )
    );

  listed =
    emit: at: field: each: value:
    if !(value ? ${field}) then
      [ ]
    else if !builtins.isList value.${field} then
      [ (malformed emit at field "a list") ]
    else
      lib.concatLists (
        lib.imap0 (
          index: entry:
          each (
            at
            ++ [
              field
              index
            ]
          ) entry
        ) value.${field}
      );
in
{
  name = "furnish";

  kinds = [
    "entry"
    "home"
  ];

  before = [ ];

  claimable = [
    [ ]
    [ "files" ]
    [ "directories" ]
    [
      "directories"
      "files"
    ]
  ];

  codes = {
    furnish-unknown-field = {
      message = args: "a furnish block has no field ${shown args "field"} at this position";
      help = "a placement takes src and dest, a directory adds exclude and files, a file group takes names";
    };

    furnish-malformed-field = {
      message = args: "${shown args "field"} must be ${prose args "expected"}";
    };
  };

  validate =
    { emit, value }:
    if !builtins.isAttrs value then
      emit.furnish-malformed-field {
        context = {
          field = "furnish";
          expected = "an attrset of placements";
        };
      }
    else
      fx.seq (
        unknown emit [ ] topKeys value
        ++ listed emit [ ] "files" (at: entry: placement emit at fileKeys entry) value
        ++ listed emit [ ] "directories" (at: entry: directory emit at entry) value
      );

  compile = {
    independent = value: {
      files = value.files or [ ];
      directories = value.directories or [ ];
    };
    dependent = _: compiled: compiled;
  };
}
