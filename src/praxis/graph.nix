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
          diagnostics = state.diagnostics ++ result.diagnostics;
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
in
fields.validation.fromDiagnostics result.diagnostics (builtins.attrNames result.seen)
