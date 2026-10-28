{
  lib,
  axiom,
  krisis,
  problem,
}:
let
  fields = import ./fields.nix {
    inherit
      lib
      axiom
      krisis
      problem
      ;
  };
  inherit (fields)
    effects
    checked
    mapChecked
    reject
    diagnostic
    field
    required
    closed
    ;
  argumentCheck = (fields.typeChecks "args-shape").arguments;
  executionCheck = (fields.typeChecks "exec-shape").arguments;
  environmentCheck = (fields.typeChecks "env-value").environment;
  nonEmptyString = fields.nonEmpty;
  relativePath = fields.relative;
  commandName = fields.name;
  envName = lib.strings.isValidPosixName;
  parameters = import ./parameters.nix { inherit lib fields; };
  inherit (fields) nullable;
  interaction = import ./interaction.nix { inherit lib fields; };
  cwdField =
    subject:
    field subject "cwd" "cwd must be an absolute string or a clean relative directory" (
      nullable (value: nonEmptyString value && (lib.hasPrefix "/" value || relativePath value))
    )
    // {
      default = null;
    };
  envField =
    subject:
    field subject "env-shape" "env must be an attribute set of strings" builtins.isAttrs
    // {
      default = { };
    };
  project =
    raw:
    let
      shape = closed "project" "praxis" {
        name = field "praxis" "name" "name must be a command-style name" commandName // {
          default = "praxis";
        };
        ui =
          if builtins.isAttrs raw && raw ? ui && raw.ui != { } then
            interaction.uiField "praxis.ui"
          else
            { default = { }; };
        pkgs = {
          required = true;
          onMissing = _: diagnostic "praxis" "pkgs" "pkgs is required";
        };
        root =
          field "praxis" "root" "root must be a Nix path containing a regular flake.nix" (
            nullable (
              value:
              builtins.isPath value
              && builtins.pathExists (value + "/flake.nix")
              && (builtins.readDir value)."flake.nix" == "regular"
            )
          )
          // {
            default = null;
          };
        cwd =
          field "praxis" "cwd" "project cwd must be an absolute runtime string" (
            nullable (value: nonEmptyString value && lib.hasPrefix "/" value)
          )
          // {
            default = null;
          };
        discoverRoot =
          field "praxis" "discover-root" "discoverRoot must be a relative marker filename" (
            nullable relativePath
          )
          // {
            default = null;
          };
        requireRoot = field "praxis" "require-root" "requireRoot must be a boolean" builtins.isBool // {
          default = false;
        };
        commands = field "praxis" "commands-shape" "commands must be an attribute set" builtins.isAttrs // {
          default = { };
        };
      } raw;
    in
    checked.andThen (
      spec:
      effects.fromDiagnostics (builtins.concatLists [
        (lib.optional (spec.cwd != null && spec.discoverRoot != null) (
          diagnostic "praxis" "root-policy" "choose cwd or discoverRoot, not both"
        ))
        (lib.optional (spec.requireRoot && spec.root == null) (
          diagnostic "praxis" "root-policy" "requireRoot needs root for the flake.nix guard"
        ))
      ]) spec
    ) (effects.fromAxiom shape);

  step =
    subject: fallbackLabel: autoForward: input:
    let
      raw = if builtins.isString input then { run = input; } else input;
      record = builtins.isAttrs raw;
      forms =
        if record then
          builtins.filter (key: builtins.hasAttr key raw) [
            "run"
            "exec"
            "script"
            "command"
            "prompt"
          ]
        else
          [ ];
      shape = closed "step" subject {
        run = { };
        exec = { };
        script = { };
        command = { };
        prompt = { };
        ui = interaction.uiField subject;
        timeout = interaction.timeoutField subject;
        when = interaction.conditionField subject;
        interpreter = { };
        rootRelative = field subject "script-root" "rootRelative must be boolean" builtins.isBool;
        label = field subject "label-shape" "label must be a non-empty string" nonEmptyString;
        args = {
          parse = argumentCheck "${subject}.args";
        }
        // {
          default = [ ];
        };
        cwd = cwdField subject;
        env = envField subject;
        interactive = field subject "interactive" "interactive must be a boolean" builtins.isBool // {
          default = false;
        };
        confirm =
          field subject "confirm" "confirm must be a non-empty prompt or null" (nullable nonEmptyString)
          // {
            default = null;
          };
        forwardArgs = field subject "forward-args" "forwardArgs must be a boolean" builtins.isBool // {
          # a sequence needs an explicit recipient instead of broadcasting arguments
          default = autoForward && !(record && raw ? prompt);
        };
      } raw;
      structural = builtins.concatLists [
        (lib.optional (record && builtins.length forms != 1) (
          diagnostic subject "execution-form" "define exactly one of run, exec, script, command or prompt"
        ))
        (lib.optional (record && raw ? interpreter && !(raw ? script)) (
          diagnostic subject "interpreter-form" "interpreter is only valid with script"
        ))
        (lib.optional (record && raw ? rootRelative && !(raw ? script)) (
          diagnostic subject "script-root" "rootRelative is only valid with script"
        ))
      ];
    in
    checked.andThen
      (
        spec:
        let
          kind = builtins.head forms;
          checks = {
            run = nonEmptyString;
            script = relativePath;
            command = fields.routeName;
          };
          execution =
            if kind == "prompt" then
              interaction.prompt subject spec.prompt
            else if kind == "exec" then
              checked.andThen (
                args:
                effects.fromDiagnostics (lib.optional (args == [ ] || !nonEmptyString (builtins.head args)) (
                  diagnostic subject "exec-shape" "exec must start with a non-empty executable string"
                )) args
              ) (effects.fromAxiom (executionCheck "${subject}.exec" spec.exec))
            else
              effects.fromDiagnostics (lib.optional (!(checks.${kind} spec.${kind})) (
                diagnostic subject (
                  if kind == "script" then "script-path" else "${kind}-shape"
                ) "invalid ${kind} value"
              )) spec.${kind};
          diagnostics = builtins.concatLists [
            (lib.optional (spec ? interpreter && !nonEmptyString spec.interpreter) (
              diagnostic subject "interpreter-shape" "interpreter must be one executable name or path"
            ))
            (lib.optional
              (
                kind == "prompt"
                && (spec.args != [ ] || spec.forwardArgs || spec.interactive || spec.confirm != null)
              )
              (diagnostic subject "prompt" "prompt steps cannot take args, forwardArgs, interactive or confirm")
            )
            (lib.optional (kind == "command" && spec.interactive) (
              diagnostic subject "interactive" "put interactive on the executable step, not a command reference"
            ))
            (environmentDiagnostics subject spec.env)
          ];
        in
        mapChecked
          (
            value:
            (
              spec
              // {
                inherit kind;
                # shell argument placement belongs to the authored source
                ${kind} = value;
                label =
                  spec.label or (
                    if kind == "exec" then
                      builtins.head spec.exec
                    else if kind == "prompt" then
                      spec.prompt.message
                    else if kind == "run" && (lib.hasInfix "\n" spec.run || builtins.stringLength spec.run > 80) then
                      fallbackLabel
                    else
                      spec.${kind}
                  );
              }
              // lib.optionalAttrs (kind == "script") { interpreter = spec.interpreter or null; }
            )
          )
          (
            mapChecked builtins.head (
              checked.all [
                execution
                (effects.fromDiagnostics diagnostics null)
              ]
            )
          )
      )
      (
        mapChecked builtins.head (
          checked.all [
            (effects.fromAxiom shape)
            (effects.fromDiagnostics structural null)
          ]
        )
      );

  environmentDiagnostics =
    subject: env:
    lib.concatMap (
      name:
      if !envName name then
        [ (diagnostic subject "env-name" "invalid environment name '${name}'") ]
      else
        (environmentCheck subject env name).diagnostics
    ) (builtins.attrNames env);

  command = normalizeCommand "commands";
  task = normalizeCommand "tasks";
  normalizeCommand =
    collection: name: input:
    let
      subject = "${collection}.${name}";
      raw =
        if builtins.isString input then
          { steps = [ input ]; }
        else if builtins.isList input then
          { steps = input; }
        else
          input;
      shape = closed "command" subject {
        kind =
          field subject "kind" "kind must be command or task" (
            v:
            builtins.elem v [
              "command"
              "task"
            ]
          )
          // {
            default = "command";
          };
        scope =
          field subject "scope" "scope must be project or global" (
            value:
            builtins.isString value
            && builtins.elem value [
              "project"
              "global"
            ]
          )
          // {
            default = "project";
          };
        ui = interaction.uiField subject;
        timeout = interaction.timeoutField subject;
        category =
          field subject "category" "category must be a non-empty string" (nullable nonEmptyString)
          // {
            default = null;
          };
        aliases =
          field subject "aliases" "aliases must be distinct command-style names" (
            v:
            builtins.isList v
            && builtins.all (a: commandName a && a != name) v
            && builtins.length v == builtins.length (axiom.sets.unique v)
          )
          // {
            default = [ ];
          };
        examples = field subject "examples" "examples must be strings" interaction.strings // {
          default = [ ];
        };
        hidden = field subject "hidden" "hidden must be boolean" builtins.isBool // {
          default = false;
        };
        deprecated =
          field subject "deprecated" "deprecated must be a notice or null" (nullable nonEmptyString)
          // {
            default = null;
          };
        parameterGroups =
          field subject "parameter-group" "parameterGroups must be a list" builtins.isList
          // {
            default = [ ];
          };
        description =
          field subject "description-shape" "description must be a string" builtins.isString
          // {
            default = "";
          };
        steps = required subject "steps-shape" "steps must be a non-empty list" (
          value: builtins.isList value && value != [ ]
        );
        runtimeInputs =
          field subject "runtime-inputs-shape" "runtimeInputs must be a list" builtins.isList
          // {
            default = [ ];
          };
        env = envField subject;
        cwd = cwdField subject;
        lock = field subject "lock" "lock must be a command-style name or null" (nullable commandName) // {
          default = null;
        };
        parameters = field subject "parameters" "parameters must be a list" builtins.isList // {
          default = [ ];
        };
      } raw;
    in
    if !fields.routeName name then
      reject [
        (diagnostic subject "command-name" "command names must match [a-zA-Z0-9][a-zA-Z0-9_-]*")
      ]
    else
      checked.andThen (
        spec:
        let
          steps = checked.all (
            lib.imap1 (
              index:
              step "${subject}.steps[${toString index}]" "${name} (step ${toString index})" (
                builtins.length spec.steps == 1
              )
            ) spec.steps
          );
          params = checked.all (
            lib.imap1 (
              index: value: parameters.parameter "${subject}.parameters[${toString index}]" value
            ) spec.parameters
          );
          groups = checked.all (
            lib.imap1 (
              i: value: effects.fromAxiom (interaction.group "${subject}.parameterGroups[${toString i}]" value)
            ) spec.parameterGroups
          );
          independent = effects.fromDiagnostics (builtins.concatLists [
            (lib.concatLists (
              lib.imap1 (
                index: input:
                lib.optional (!lib.isDerivation input) (
                  diagnostic subject "runtime-input" "runtimeInputs[${toString index}] must be a package derivation"
                )
              ) spec.runtimeInputs
            ))
            (environmentDiagnostics subject spec.env)
          ]) null;
        in
        checked.andThen
          (
            values:
            let
              groups = builtins.elemAt values 0;
              steps = builtins.elemAt values 2;
              params = builtins.elemAt values 3;
              sensitive = lib.filter (p: p.sensitive) params;
              sensitiveNames = map (p: p.name) sensitive;
              sensitiveEnv = lib.concatMap (
                p: [ "PRAXIS_ARG_${parameters.envKey p.name}" ] ++ lib.optional (p.env != null) p.env
              ) sensitive;
              names = map (p: p.name) params;
              parameterNames = axiom.sets.index names;
              parameterSpecs = builtins.listToAttrs (
                map (p: {
                  inherit (p) name;
                  value = p;
                }) params
              );
              environmentNames = builtins.groupBy parameters.envKey names;
              # named flags do not participate in positional ordering
              ordering =
                builtins.foldl'
                  (
                    state: p:
                    if state.invalid || !p.positional then
                      state
                    else if p.required then
                      {
                        inherit (state) optional;
                        invalid = state.optional;
                      }
                    else
                      {
                        optional = true;
                        invalid = false;
                      }
                  )
                  {
                    optional = false;
                    invalid = false;
                  }
                  params;
              shorts = builtins.filter (v: v != null) (map (p: p.short) params);
              semantic = builtins.concatLists [
                (lib.optional (builtins.length shorts != builtins.length (axiom.sets.unique shorts)) (
                  diagnostic subject "parameter-short" "short flags must be unique"
                ))
                (lib.concatMap (
                  g:
                  lib.optional
                    (builtins.any (
                      n: !(builtins.hasAttr n parameterNames) || builtins.elem n sensitiveNames
                    ) g.parameters)
                    (diagnostic subject "parameter-group" "groups must name declared, non-sensitive parameters")
                ) groups)
                (lib.concatMap (
                  s:
                  builtins.concatLists [
                    (parameters.references subject parameterNames (
                      map (param: { inherit param; }) (builtins.attrNames s.when.parameters)
                    ))
                    (parameters.conditionDiagnostics subject parameterSpecs s.when.parameters)
                    (lib.optional (
                      builtins.any (a: builtins.isAttrs a && builtins.elem a.param sensitiveNames) (
                        s.args ++ (s.exec or [ ])
                      )
                      || builtins.any (n: builtins.elem n sensitiveNames) (builtins.attrNames (s.when.parameters or { }))
                    ) (diagnostic subject "parameter-sensitive" "sensitive values cannot appear in argv or conditions"))
                    (lib.optional
                      (builtins.any (
                        n: builtins.hasAttr n s.env || builtins.hasAttr n spec.env || builtins.hasAttr n (s.when.env or { })
                      ) sensitiveEnv)
                      (
                        diagnostic subject "parameter-sensitive"
                          "sensitive environment sources cannot be overridden or inspected by conditions"
                      )
                    )
                  ]
                ) steps)
                (lib.optional (builtins.length names != builtins.length (builtins.attrNames environmentNames)) (
                  diagnostic subject "parameter-name" "parameter names must have unique environment names"
                ))
                (lib.optional ordering.invalid (
                  diagnostic subject "parameter-order" "required positional arguments must precede optional ones"
                ))
                (lib.optional (builtins.length (builtins.filter (s: s.forwardArgs) steps) > 1) (
                  diagnostic subject "forward-args" "at most one step may receive pass-through arguments"
                ))
                (lib.concatMap (s: parameters.references subject parameterNames (s.args ++ (s.exec or [ ]))) steps)
              ];
            in
            effects.fromDiagnostics semantic (
              spec
              // {
                steps = map (
                  s:
                  s
                  // {
                    when = s.when // {
                      parameters = builtins.mapAttrs (_: fields.text) s.when.parameters;
                    };
                  }
                ) steps;
                parameters = params;
                parameterGroups = groups;
              }
            )
          )
          (
            checked.all [
              groups
              independent
              steps
              params
            ]
          )
      ) (effects.fromAxiom shape);
in
{
  inherit project command task;
}
