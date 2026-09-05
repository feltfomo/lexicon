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
    validation
    diagnostic
    field
    required
    closed
    ;
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
        ui = interaction.uiField "praxis.ui";
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
    validation.andThen (
      spec:
      validation.fromDiagnostics (validation.collect [
        (validation.optional (spec.cwd != null && spec.discoverRoot != null) (
          diagnostic "praxis" "root-policy" "choose cwd or discoverRoot, not both"
        ))
        (validation.optional (spec.requireRoot && spec.root == null) (
          diagnostic "praxis" "root-policy" "requireRoot needs root for the flake.nix guard"
        ))
      ]) spec
    ) shape;

  step =
    subject: fallbackLabel: input:
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
        label = field subject "label-shape" "label must be a non-empty string" nonEmptyString;
        args = fields.typed "${subject}.args" "args-shape" parameters.argumentsType // {
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
          default = false;
        };
      } raw;
      structural = validation.collect [
        shape.diagnostics
        (validation.optional (record && builtins.length forms != 1) (
          diagnostic subject "execution-form" "define exactly one of run, exec, script, command or prompt"
        ))
        (validation.optional (record && raw ? interpreter && !(raw ? script)) (
          diagnostic subject "interpreter-form" "interpreter is only valid with script"
        ))
      ];
    in
    validation.andThen (
      spec:
      let
        kind = builtins.head forms;
        checks = {
          run = nonEmptyString;
          script = relativePath;
          command = commandName;
        };
        execution =
          if kind == "prompt" then
            interaction.prompt subject spec.prompt
          else if kind == "exec" then
            validation.andThen (
              args:
              validation.fromDiagnostics (validation.optional (
                args == [ ] || !nonEmptyString (builtins.head args)
              ) (diagnostic subject "exec-shape" "exec must start with a non-empty executable string")) args
            ) (fields.validateType "${subject}.exec" "exec-shape" parameters.argumentsType spec.exec)
          else
            validation.fromDiagnostics (validation.optional (!(checks.${kind} spec.${kind})) (
              diagnostic subject (
                if kind == "script" then "script-path" else "${kind}-shape"
              ) "invalid ${kind} value"
            )) spec.${kind};
        diagnostics = validation.collect [
          execution.diagnostics
          (validation.optional (spec ? interpreter && !nonEmptyString spec.interpreter) (
            diagnostic subject "interpreter-shape" "interpreter must be one executable name or path"
          ))
          (validation.optional
            (
              kind == "prompt"
              && (spec.args != [ ] || spec.forwardArgs || spec.interactive || spec.confirm != null)
            )
            (diagnostic subject "prompt" "prompt steps cannot take args, forwardArgs, interactive or confirm")
          )
          (validation.optional (kind == "command" && spec.interactive) (
            diagnostic subject "interactive" "put interactive on the executable step, not a command reference"
          ))
          (environmentDiagnostics subject spec.env)
        ];
      in
      validation.fromDiagnostics diagnostics (
        spec
        // {
          inherit kind;
          ${kind} = execution.value;
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
    ) (validation.fromDiagnostics structural shape.value);

  environmentDiagnostics =
    subject: env:
    lib.concatMap (
      name:
      if !envName name then
        [ (diagnostic subject "env-name" "invalid environment name '${name}'") ]
      else
        (krisis.validateType {
          type = axiom.types.string;
          code = "praxis/env-value";
          label = subject;
          path = [
            "env"
            name
          ];
        } env.${name}).diagnostics
    ) (builtins.attrNames env);

  command =
    name: input:
    let
      subject = "commands.${name}";
      raw =
        if builtins.isString input then
          { steps = [ input ]; }
        else if builtins.isList input then
          { steps = input; }
        else
          input;
      shape = closed "command" subject {
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
            && builtins.all (a: commandName a && a != name && a != "praxis") v
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
            default = "Run ${name}";
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
    if !commandName name || name == "praxis" then
      validation.failure [
        (diagnostic subject "command-name"
          "command names must match [a-zA-Z0-9][a-zA-Z0-9_-]*; praxis is reserved"
        )
      ]
    else
      validation.andThen (
        spec:
        let
          steps = validation.sequence (
            lib.imap1 (
              index: step "${subject}.steps[${toString index}]" "${name} (step ${toString index})"
            ) spec.steps
          );
          params = validation.sequence (
            lib.imap1 (index: parameters.parameter "${subject}.parameters[${toString index}]") spec.parameters
          );
          groups = validation.sequence (
            lib.imap1 (i: interaction.group "${subject}.parameterGroups[${toString i}]") spec.parameterGroups
          );
          sensitive = lib.filter (p: p.sensitive) params.value;
          sensitiveNames = map (p: p.name) sensitive;
          sensitiveEnv = lib.concatMap (
            p: [ "PRAXIS_ARG_${parameters.envKey p.name}" ] ++ lib.optional (p.env != null) p.env
          ) sensitive;
          diagnostics = validation.collect [
            groups.diagnostics
            (lib.concatLists (
              lib.imap1 (
                index: input:
                validation.optional (!lib.isDerivation input) (
                  diagnostic subject "runtime-input" "runtimeInputs[${toString index}] must be a package derivation"
                )
              ) spec.runtimeInputs
            ))
            (environmentDiagnostics subject spec.env)
            steps.diagnostics
            params.diagnostics
          ];
          names = map (p: p.name) params.value;
          parameterNames = axiom.sets.index names;
          parameterSpecs = builtins.listToAttrs (
            map (p: {
              inherit (p) name;
              value = p;
            }) params.value
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
              params.value;
          shorts = builtins.filter (v: v != null) (map (p: p.short) params.value);
          semantic = validation.collect [
            (validation.optional (builtins.length shorts != builtins.length (axiom.sets.unique shorts)) (
              diagnostic subject "parameter-short" "short flags must be unique"
            ))
            (lib.concatMap (
              g:
              validation.optional
                (builtins.any (
                  n: !(builtins.hasAttr n parameterNames) || builtins.elem n sensitiveNames
                ) g.parameters)
                (diagnostic subject "parameter-group" "groups must name declared, non-sensitive parameters")
            ) groups.value)
            (lib.concatMap (
              s:
              validation.collect [
                (parameters.references subject parameterNames (
                  map (param: { inherit param; }) (builtins.attrNames s.when.parameters)
                ))
                (parameters.conditionDiagnostics subject parameterSpecs s.when.parameters)
                (validation.optional (
                  builtins.any (a: builtins.isAttrs a && builtins.elem a.param sensitiveNames) (
                    s.args ++ (s.exec or [ ])
                  )
                  || builtins.any (n: builtins.elem n sensitiveNames) (builtins.attrNames (s.when.parameters or { }))
                ) (diagnostic subject "parameter-sensitive" "sensitive values cannot appear in argv or conditions"))
                (validation.optional
                  (builtins.any (
                    n: builtins.hasAttr n s.env || builtins.hasAttr n spec.env || builtins.hasAttr n (s.when.env or { })
                  ) sensitiveEnv)
                  (
                    diagnostic subject "parameter-sensitive"
                      "sensitive environment sources cannot be overridden or inspected by conditions"
                  )
                )
              ]
            ) steps.value)
            (validation.optional (
              builtins.length names != builtins.length (builtins.attrNames environmentNames)
            ) (diagnostic subject "parameter-name" "parameter names must have unique environment names"))
            (validation.optional ordering.invalid (
              diagnostic subject "parameter-order" "required positional arguments must precede optional ones"
            ))
            (validation.optional (builtins.length (builtins.filter (s: s.forwardArgs) steps.value) > 1) (
              diagnostic subject "forward-args" "at most one step may receive pass-through arguments"
            ))
            (lib.concatMap (
              s: parameters.references subject parameterNames (s.args ++ (s.exec or [ ]))
            ) steps.value)
          ];
        in
        validation.andThen (
          _:
          validation.fromDiagnostics semantic (
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
              ) steps.value;
              parameters = params.value;
              parameterGroups = groups.value;
            }
          )
        ) (validation.fromDiagnostics diagnostics null)
      ) shape;
in
{
  inherit project command;
}
