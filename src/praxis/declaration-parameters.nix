{ lib, fields }:
subject: raw: positional:
let
  inherit (fields) validation diagnostic;
  parameterName =
    value: builtins.isString value && builtins.match "[a-zA-Z][a-zA-Z0-9-]*" value != null;
  shape = validation.collect [
    (validation.optional (!builtins.isAttrs raw) (
      diagnostic subject "parameters" "parameters must be an attribute set keyed by parameter name"
    ))
    (validation.optional
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
validation.andThen (
  _:
  validation.andThen
    (
      _:
      validation.sequence (
        map
          (
            name:
            validation.andThen (
              value:
              validation.success (
                value
                // {
                  inherit name;
                  positional = builtins.hasAttr name positionals;
                  required = value.required or (builtins.hasAttr name positionals && (value.default or null) == null);
                }
              )
            ) (fields.closed "parameter" "${subject}.parameters.${name}" descriptors raw.${name})
          )
          (
            positional ++ builtins.filter (name: !(builtins.hasAttr name positionals)) (builtins.attrNames raw)
          )
      )
    )
    (
      validation.fromDiagnostics (validation.collect [
        (lib.concatMap (
          name:
          validation.optional (!parameterName name) (
            diagnostic "${subject}.parameters.${name}" "parameter-name" "invalid parameter name"
          )
        ) (builtins.attrNames raw))
        (validation.optional (builtins.any (name: !(builtins.hasAttr name raw)) positional) (
          diagnostic subject "positional" "positional arguments must name declared parameters"
        ))
      ]) null
    )
) (validation.fromDiagnostics shape null)
