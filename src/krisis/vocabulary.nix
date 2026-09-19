# a subsystem declares every code it can report, once. the emitters are built
# from that declaration, so a bad code name fails at import
{
  lib,
  fx,
  emit,
  render,
  path,
  severities,
}:
let
  fail = message: throw "krisis: ${message}";

  Severity = fx.types.refined "Severity" fx.types.String (value: builtins.elem value severities);

  Namespace = fx.types.refined "Namespace" fx.types.String (
    value: value != "" && builtins.match "[a-z][a-z0-9-]*" value != null
  );

  # local names. the namespace gets bound once, by the vocabulary
  CodeName = fx.types.refined "CodeName" fx.types.String (
    value: value != "" && builtins.match "[a-z0-9]+(-[a-z0-9]+)*" value != null
  );

  Notes = fx.types.ListOf fx.types.String;

  declarationFields = [
    "message"
    "severity"
    "help"
    "notes"
  ];

  vocabularyFields = [
    "namespace"
    "source"
    "severity"
    "codes"
  ];

  reservedArgs = [
    "at"
    "source"
    "severity"
    "notes"
    "help"
    "context"
  ];

  closed =
    what: allowed: attrs:
    let
      unknown = builtins.filter (name: !builtins.elem name allowed) (builtins.attrNames attrs);
    in
    lib.optional (unknown != [ ]) "${what}: unknown field '${builtins.head unknown}'";

  # fx records are open, so the unknown-field check is ours. 'hepl' should
  # fail rather than quietly become a field nobody reads
  checkDeclaration =
    name: declaration:
    let
      prefix = "code '${name}'";
    in
    lib.optional (!CodeName.check name) "code name '${name}' must be lowercase and hyphen-separated"
    ++ lib.optional (!builtins.isAttrs declaration) "${prefix}: declaration must be an attrset"
    ++ lib.optionals (builtins.isAttrs declaration) (
      closed prefix declarationFields declaration
      ++ lib.optional (!(declaration ? message)) "${prefix}: declaration must define a message"
      ++ lib.optional (
        declaration ? message
        && !(builtins.isString declaration.message || builtins.isFunction declaration.message)
      ) "${prefix}: message must be a string or a function of the emit arguments"
      ++ lib.optional (
        declaration ? severity && !Severity.check declaration.severity
      ) "${prefix}: severity must be one of ${lib.concatStringsSep ", " severities}"
      ++ lib.optional (
        declaration ? help && !builtins.isString declaration.help
      ) "${prefix}: help must be a string"
      ++ lib.optional (
        declaration ? notes && !Notes.check declaration.notes
      ) "${prefix}: notes must be a list of strings"
    );

  checkVocabulary =
    spec:
    closed "vocabulary" vocabularyFields spec
    ++ lib.optional (
      !(spec ? namespace) || !Namespace.check (spec.namespace or null)
    ) "vocabulary: namespace must be a lowercase identifier"
    ++ lib.optional (
      spec ? source && !builtins.isString spec.source
    ) "vocabulary: source must be a string"
    ++ lib.optional (
      spec ? severity && !Severity.check spec.severity
    ) "vocabulary: severity must be one of ${lib.concatStringsSep ", " severities}"
    ++ lib.optional (
      !(spec ? codes) || !builtins.isAttrs spec.codes || spec.codes == { }
    ) "vocabulary: codes must be a non-empty attrset"
    ++ lib.optionals (spec ? codes && builtins.isAttrs spec.codes) (
      lib.concatLists (lib.mapAttrsToList checkDeclaration spec.codes)
    );

  sequence =
    comps:
    builtins.foldl' (acc: comp: fx.bind acc (values: fx.map (value: values ++ [ value ]) comp)) (fx.pure
      [ ]
    ) comps;

  # context values cross the render boundary before a message can see them
  renderContext =
    context:
    let
      names = builtins.attrNames context;
    in
    fx.map (values: lib.listToAttrs (lib.zipListsWith lib.nameValuePair names values)) (
      names |> map (name: render.show context.${name}) |> sequence
    );

  mkVocabulary =
    spec:
    let
      problems = checkVocabulary spec;

      inherit (spec) namespace;
      source = spec.source or namespace;
      defaultSeverity = spec.severity or "error";

      qualify = name: "${namespace}/${name}";

      messageOf =
        name: declaration: args:
        let
          result =
            if builtins.isString declaration.message then declaration.message else declaration.message args;
        in
        if builtins.isString result then
          result
        else
          fail "code '${qualify name}' produced a ${builtins.typeOf result} message; messages must be strings";

      mkEmitter =
        name: declaration: args:
        let
          given = if args == null then { } else args;
          context = given.context or { };
        in
        if !builtins.isAttrs given then
          fail "code '${qualify name}' was emitted with a ${builtins.typeOf given}; emit arguments must be an attrset"
        else if !builtins.isAttrs context then
          fail "code '${qualify name}': context must be an attrset of values to render"
        else
          fx.bind (renderContext context) (
            rendered:
            emit.report {
              code = qualify name;
              severity = given.severity or declaration.severity or defaultSeverity;
              source = given.source or source;
              at = if given ? at then path.renderPath given.at else null;
              message = messageOf name declaration (given // { inherit rendered; });
              notes = given.notes or declaration.notes or [ ];
              help = given.help or declaration.help or null;
              inherit rendered;
            }
          );

      emitters = lib.mapAttrs mkEmitter spec.codes;

      catalogue = lib.mapAttrsToList (name: declaration: {
        code = qualify name;
        severity = declaration.severity or defaultSeverity;
        help = declaration.help or null;
        notes = declaration.notes or [ ];
      }) spec.codes;
    in
    if problems != [ ] then
      fail (lib.concatStringsSep "; " problems)
    else
      {
        inherit
          namespace
          source
          catalogue
          ;
        codes = builtins.attrNames spec.codes |> map qualify;
        emit = emitters;
        reserved = reservedArgs;
      };
in
{
  vocabulary = mkVocabulary;
}
