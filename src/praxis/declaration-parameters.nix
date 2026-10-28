{ lib, fields }:
subject: raw: positional:
let
  inherit (fields)
    effects
    checked
    diagnostic
    ;
  parameterName =
    value: builtins.isString value && builtins.match "[a-zA-Z][a-zA-Z0-9-]*" value != null;
  shape = builtins.concatLists [
    (lib.optional (!builtins.isAttrs raw) (
      diagnostic subject "parameters" "parameters must be an attribute set keyed by parameter name"
    ))
    (lib.optional
      (
        !builtins.isList positional
        || !builtins.all parameterName positional
        || builtins.length positional != builtins.length (fields.sets.unique positional)
      )
      (diagnostic subject "positional" "positional must list distinct parameter names in argument order")
    )
  ];
  descriptors = lib.genAttrs [
    "description"
    "type"
    "required"
    "env"
    "short"
    "sensitive"
    "choices"
    "default"
  ] (_: { });
  positionals = fields.sets.index positional;
in
checked.andThen (
  _:
  checked.andThen
    (
      _:
      checked.all (
        map
          (
            name:
            checked.andThen (
              value:
              effects.accept (
                value
                // {
                  inherit name;
                  positional = builtins.hasAttr name positionals;
                  required = value.required or (builtins.hasAttr name positionals && (value.default or null) == null);
                }
              )
            ) (fields.checkedClosed "parameter" "${subject}.parameters.${name}" descriptors raw.${name})
          )
          (
            positional ++ builtins.filter (name: !(builtins.hasAttr name positionals)) (builtins.attrNames raw)
          )
      )
    )
    (
      effects.fromDiagnostics (builtins.concatLists [
        (lib.concatMap (
          name:
          lib.optional (!parameterName name) (
            diagnostic "${subject}.parameters.${name}" "parameter-name" "invalid parameter name"
          )
        ) (builtins.attrNames raw))
        (lib.optional (builtins.any (name: !(builtins.hasAttr name raw)) positional) (
          diagnostic subject "positional" "positional arguments must name declared parameters"
        ))
      ]) null
    )
) (effects.fromDiagnostics shape null)
