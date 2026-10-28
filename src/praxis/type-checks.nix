{
  lib,
  axiom,
  krisis,
  diagnostic,
  nonEmpty,
  name,
}:
let
  inherit (krisis) effects;
  inherit (effects.native) validation;
  T = validation.types;
  scalarTypes = {
    string = T.String;
    int = T.Int;
    bool = T.Bool;
    path = T.refined "non-empty runtime path string" T.String nonEmpty;
  };
  choiceTypes = builtins.mapAttrs (_: T.ListOf) scalarTypes;
  defaultTypes = builtins.mapAttrs (_: T.Maybe) scalarTypes;
  argumentsShape = T.ListOf T.Any;
  referenceShape = T.refined "record containing only param" T.Attrs (
    value: builtins.attrNames value == [ "param" ]
  );
  referenceBody = T.Record {
    param = T.refined "command-style parameter name" T.String name;
  };
  expectedNames = {
    String = "string";
    Int = "int";
    Bool = "bool";
    Attrs = "set";
    "Record{param}" = "record";
    "non-empty runtime path string" = "non-empty runtime path string";
    "record containing only param" = "record containing only param";
    "command-style parameter name" = "command-style parameter name";
    "List[Any]" = "list of string or parameter reference";
  };
  expected =
    value:
    if builtins.hasAttr value expectedNames then
      expectedNames.${value}
    else if lib.hasPrefix "List[" value then
      "list of ${expected (lib.removeSuffix "]" (lib.removePrefix "List[" value))}"
    else
      throw "praxis: unknown native validation type '${value}'";
  reasons = {
    shape-mismatch = "type";
    predicate-failed = "refinement";
    missing-field = "missing-field";
    extra-field = "unknown-field";
  };
in
code:
let
  native =
    type:
    validation.check {
      inherit type;
      code = "praxis/${code}";
    };
  scalarChecks = builtins.mapAttrs (_: native) scalarTypes;
  choiceChecks = builtins.mapAttrs (_: native) choiceTypes;
  defaultChecks = builtins.mapAttrs (_: native) defaultTypes;
  stringCheck = scalarChecks.string;
  shapeCheck = native referenceShape;
  bodyCheck = native referenceBody;
  argumentsCheck = native argumentsShape;
  # native blame is adapted once at the retained schema callback boundary
  project =
    subject: path:
    let
      adapt =
        d:
        let
          issue = d.context.validation;
          reason =
            reasons.${issue.reason} or (throw "praxis: unknown native validation reason '${issue.reason}'");
          located = {
            path = path ++ map (part: part.field or part.index) issue.path;
            inherit reason;
            expected = if reason == "unknown-field" then "declared field" else expected issue.expected;
            actual =
              if reason == "missing-field" then
                "missing"
              else if reason == "unknown-field" then
                "unknown"
              else
                issue.actual;
          };
        in
        (diagnostic subject code
          "${krisis.renderPath located.path}: expected ${located.expected}; got ${located.actual}"
        )
        // {
          context.validation = located;
        };
    in
    effects.mappedResultFromReport adapt;
  check =
    subject: path: checker: value:
    project subject path (effects.interpret (checker value));
  # malformed reference names must not force the parameter payload
  reference =
    subject: path: value:
    project subject path (
      effects.interpret (validation.andThen (_: bodyCheck value) (shapeCheck value))
    );
  argument =
    subject: path: value:
    if builtins.isString value then
      axiom.validation.success value
    else
      let
        result = reference subject path value;
      in
      if axiom.validation.isSuccess result then
        axiom.validation.success value
      else
        let
          fallback = check subject path stringCheck value;
        in
        axiom.validation.failure (fallback.diagnostics ++ result.diagnostics);
  arguments =
    subject: values:
    let
      outer = check subject [ ] argumentsCheck values;
    in
    if !axiom.validation.isSuccess outer then
      outer
    else
      let
        members = lib.imap0 (index: argument subject [ index ]) values;
        settled = builtins.foldl' (unit: result: builtins.seq result.diagnostics unit) null members;
        diagnostics = builtins.concatLists (map (result: result.diagnostics) members);
      in
      builtins.seq settled (
        if diagnostics == [ ] then axiom.validation.success values else axiom.validation.failure diagnostics
      );
in
{
  inherit arguments;
  scalar =
    subject: kind: value:
    check subject [ ] scalarChecks.${kind} value;
  choices =
    subject: kind: value:
    check subject [ ] choiceChecks.${kind} value;
  default =
    subject: kind: value:
    check subject [ ] defaultChecks.${kind} value;
  environment =
    subject: env: key:
    check subject [ "env" key ] stringCheck env.${key};
}
