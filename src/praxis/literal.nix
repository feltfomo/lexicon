{ fields }:
let
  inherit (fields) lib;
in
name: argv:
let
  inherit (fields)
    effects
    diagnostic
    ;
  diagnostics = lib.optional (argv == [ ] || !fields.nonEmpty (builtins.head argv)) (
    diagnostic "commands.${name}" "exec-shape" "exec must start with a non-empty executable string"
  );
  # literal argv needs no parameter, task or interaction parsers
  value = {
    kind = "command";
    scope = "project";
    description = "";
    aliases = [ ];
    examples = [ ];
    parameters = [ ];
    parameterGroups = [ ];
    runtimeInputs = [ ];
    category = null;
    deprecated = null;
    hidden = false;
    cwd = null;
    lock = null;
    timeout = null;
    env = { };
    ui = { };
    steps = [
      {
        kind = "exec";
        exec = argv;
        label = builtins.head argv;
        args = [ ];
        forwardArgs = true;
        interactive = false;
        confirm = null;
        timeout = null;
        cwd = null;
        env = { };
        ui = { };
        when = {
          parameters = { };
          platforms = [ ];
          env = { };
        };
      }
    ];
  };
in
effects.fromDiagnostics diagnostics value
