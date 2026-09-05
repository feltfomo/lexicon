{
  lib,
  fields,
  results,
}:
let
  inherit (fields) diagnostic;
  # selections share adjacency, but only a reached command forces its steps.
  references = builtins.mapAttrs (_: result: builtins.catAttrs "command" result.value.steps) results;
  visit =
    stack: state: name:
    if builtins.elem name stack then
      state
      // {
        diagnostics = state.diagnostics ++ [
          (diagnostic "commands.${name}" "command-cycle"
            "command cycle ${lib.concatStringsSep " -> " (stack ++ [ name ])}"
          )
        ];
      }
    else if builtins.hasAttr name state.seen then
      state
    else if !(builtins.hasAttr name results) then
      state
      // {
        seen = state.seen // {
          ${name} = true;
        };
        diagnostics = state.diagnostics ++ [
          (diagnostic "commands.${name}" "command-reference" "unknown command '${name}'")
        ];
      }
    else
      let
        result = results.${name};
        current = state // {
          seen = state.seen // {
            ${name} = true;
          };
          diagnostics =
            state.diagnostics
            ++ result.diagnostics
            ++ fields.validation.optional (
              result.diagnostics == [ ]
              && builtins.any (alias: builtins.hasAttr alias results) result.value.aliases
            ) (diagnostic "commands.${name}" "aliases" "aliases cannot shadow command names");
        };
      in
      if result.diagnostics != [ ] then
        current
      else
        lib.foldl' (visit (stack ++ [ name ])) current references.${name};
in
names:
let
  result = lib.foldl' (visit [ ]) {
    seen = { };
    diagnostics = [ ];
  } names;
  selected = builtins.attrNames result.seen;
  commands = map (name: {
    inherit name;
    value = results.${name}.value;
  }) selected;
  aliasOwners = builtins.groupBy (entry: entry.alias) (
    lib.concatMap (
      entry:
      map (alias: {
        inherit alias;
        owner = entry.name;
      }) entry.value.aliases
    ) commands
  );
  aliasDiagnostics = lib.concatMap (
    alias:
    fields.validation.optional (builtins.length aliasOwners.${alias} > 1) (
      diagnostic "commands" "aliases"
        "alias '${alias}' belongs to multiple commands ${
          lib.concatStringsSep ", " (map (entry: entry.owner) aliasOwners.${alias})
        }"
    )
  ) (builtins.attrNames aliasOwners);
  # classify names before any runtime source can become an ordinary default
  sensitiveEnv = fields.sets.index (
    lib.concatMap (
      entry:
      lib.concatMap (p: [ "PRAXIS_ARG_${fields.envKey p.name}" ] ++ lib.optional (p.env != null) p.env) (
        builtins.filter (p: p.sensitive) entry.value.parameters
      )
    ) commands
  );
  protected = names: builtins.any (name: builtins.hasAttr name sensitiveEnv) names;
  secretDiagnostics = lib.concatMap (
    entry:
    let
      command = entry.value;
      conflict =
        protected (builtins.attrNames command.env)
        || builtins.any (
          p:
          !p.sensitive
          && (protected [ "PRAXIS_ARG_${fields.envKey p.name}" ] || (p.env != null && protected [ p.env ]))
        ) command.parameters
        || builtins.any (
          step:
          protected (builtins.attrNames step.env ++ builtins.attrNames step.when.env)
          || (
            step.kind == "prompt"
            && step.prompt.name != null
            && protected [ "PRAXIS_PROMPT_${fields.envKey step.prompt.name}" ]
          )
        ) command.steps;
    in
    fields.validation.optional conflict (
      diagnostic "commands.${entry.name}" "parameter-sensitive"
        "sensitive environment names cannot feed ordinary defaults, overrides, conditions or prompt responses"
    )
  ) commands;
  diagnostics =
    result.diagnostics
    ++ lib.optionals (result.diagnostics == [ ]) (aliasDiagnostics ++ secretDiagnostics);
in
fields.validation.fromDiagnostics diagnostics selected
