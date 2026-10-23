{
  lib,
  axiom,
  krisis,
}:
let
  report = import ../declarations/report.nix { inherit lib axiom krisis; };
  legacyReport = import ../program/report.nix { inherit lib axiom krisis; };
  contract = import ../furnish/contract.nix { inherit lib axiom; };
  fields = import ../program/fields.nix {
    inherit lib axiom;
  };
  links = import ./links.nix { inherit lib axiom krisis; };
  problem = krisis.mkDiagnosticFactory {
    severity = "error";
    codePrefix = "lexicon/resource";
  };
  optional = validate: {
    inherit validate;
    onInvalid =
      _: _:
      problem {
        code = "shape";
        message = "invalid resource field";
      };
  };
  required =
    validate:
    optional validate
    // {
      required = true;
      onMissing =
        _:
        problem {
          code = "required";
          message = "required resource field is missing";
        };
    };
  lifecycle = {
    representation = optional report.nonempty;
    onConflict = optional (v: builtins.elem v (builtins.attrValues contract.conflictPolicies));
    provenance = optional builtins.isString;
  };
  schemas = {
    file = lifecycle // {
      source = {
        required = true;
        onMissing =
          _:
          problem {
            code = "source";
            message = "source is required";
          };
      };
      destination = required report.nonempty;
      label = optional builtins.isString;
    };
    "external-link" = links.fields;
    directory = lifecycle // {
      source = required (v: builtins.isPath v || builtins.isString v);
      destination = required report.nonempty;
      exclude = optional (v: builtins.isList v && builtins.all fields.validRelativePath v);
    };
    rule = lifecycle // {
      names = required (v: builtins.isList v && v != [ ] && builtins.all fields.validRelativePath v);
    };
  };
  legacy =
    kind: value:
    removeAttrs value [
      "source"
      "destination"
    ]
    // lib.optionalAttrs (value ? source) {
      ${if kind == "external-link" then "target" else "src"} = value.source;
    }
    // lib.optionalAttrs (value ? destination) { dest = value.destination; };
  directoryLib = import ../program/directories.nix {
    inherit
      lib
      axiom
      krisis
      fields
      ;
    inherit (legacyReport) problem;
    directoryShapeErrors = _: [ ];
    directoryRuleErrors = _: [ ];
  };
  theme = import ../program/theme {
    inherit lib axiom contract;
    inherit (fields)
      unknownFields
      validRelativePath
      validBaseName
      validSubdir
      ;
    inherit (legacyReport) duplicateValues problem reporter;
  };
  validate =
    kind: origin: value:
    report.finish ((report.schema origin schemas.${kind}) value);
  prepareDirectory = { structure, origins }: {
    reservedNames = builtins.concatMap (
      rule:
      if builtins.isAttrs rule && builtins.isList (rule.names or null) then
        builtins.filter builtins.isString rule.names
      else
        [ ]
    ) (structure.files or [ ]);
    inventory = directoryLib.prewalkDirectory {
      index = origins.self;
      entry = legacy "directory" (
        validate "directory" origins.self (builtins.intersectAttrs schemas.directory structure)
      );
    };
  };
  validatePlan =
    plan:
    let
      ruleOrigin =
        index:
        if plan ? prepared.ruleOrigins then
          (builtins.elemAt plan.prepared.ruleOrigins index).self
        else
          plan.origin
          ++ [
            "files"
            index
          ];
      payload =
        if plan.kind == "theme" then
          axiom.validation.andThen
            (
              value:
              axiom.validation.map (entry: value // { inherit entry; }) (
                (theme.themeEntrySchema (krisis.renderPath plan.origin) (
                  lib.mapAttrs (_: krisis.renderPath) (plan.prepared.fieldOrigins or { })
                ))
                  value.entry
              )
            )
            (
              (report.schema plan.origin {
                renderer = required (name: builtins.elem name theme.themeBackends);
                blockId = required fields.validBaseName;
                entry = required builtins.isAttrs;
              })
                plan.value
            )
        else if plan.kind == "directory" then
          axiom.validation.andThen
            (
              value:
              axiom.validation.map (rules: value // lib.optionalAttrs (value ? files) { files = rules; }) (
                axiom.validation.sequence (
                  lib.imap0 (index: rule: (report.schema (ruleOrigin index) schemas.rule) rule) (value.files or [ ])
                )
              )
            )
            (
              (report.schema plan.origin (schemas.directory // { files = optional builtins.isList; })) plan.value
            )
        else if plan.kind == "external-link" then
          links.validate plan.origin plan.value
        else
          (report.schema plan.origin schemas.${plan.kind}) plan.value;
    in
    axiom.validation.map (value: plan // { inherit value; }) payload;
  compose =
    resources:
    let
      plans = report.finish (axiom.validation.sequence (map validatePlan resources));
      themePlans = builtins.filter (plan: plan.kind == "theme") plans;
      normalizedThemes = map (
        plan: theme.normalizeEntry plan.value // { inherit (plan) origin; }
      ) themePlans;
      directoryPlans = builtins.filter (plan: plan.kind == "directory") plans;
      expanded = map (
        plan:
        let
          preparation =
            plan.prepared or (prepareDirectory {
              structure = plan.value;
              origins.self = plan.origin;
            });
          index = plan.origin;
          rules = map (entry: { inherit index entry; }) (plan.value.files or [ ]);
        in
        directoryLib.expandDirectory {
          inherit index;
          entry = legacy "directory" (removeAttrs plan.value [ "files" ]);
          inherit (preparation) reservedNames;
        } rules normalizedThemes preparation.inventory
      ) directoryPlans;
      directoryFiles = report.checked (builtins.concatMap (result: result.errors) expanded) (
        builtins.concatMap (result: result.files) expanded
      );
    in
    {
      files =
        map (plan: legacy "file" plan.value) (builtins.filter (plan: plan.kind == "file") plans)
        ++ directoryFiles;
      links = builtins.concatMap (plan: map (legacy "external-link") (links.expand plan)) (
        builtins.filter (plan: plan.kind == "external-link") plans
      );
      themeEntries = normalizedThemes;
    };
in
{
  inherit
    schemas
    prepareDirectory
    validatePlan
    compose
    theme
    fields
    contract
    ;
}
