{
  lib,
  axiom,
  krisis,
  problem,
  fields,
  spec,
  schema ? import ./schema.nix {
    inherit
      lib
      axiom
      krisis
      problem
      ;
  },
}:
let
  inherit (fields) validation diagnostic closed;
  literal = import ./literal.nix { inherit fields; };
  metadata = [
    "description"
    "category"
    "aliases"
    "examples"
    "hidden"
    "deprecated"
    "scope"
    "env"
    "cwd"
    "lock"
    "timeout"
    "ui"
    "parameters"
    "parameterGroups"
  ];
  actionKeys = [
    "command"
    "shell"
    "script"
    "prompt"
    "interpreter"
    "args"
    "forwardArgs"
    "interactive"
    "confirm"
    "label"
    "condition"
    "cwd"
    "env"
    "timeout"
    "ui"
    "localFlake"
  ];
  descriptors = names: lib.genAttrs names (_: { });
  failure =
    subject: code: message:
    validation.failure [ (diagnostic subject code message) ];
  script =
    subject: value:
    if !builtins.isPath value then
      validation.success value
    else if spec.root == null then
      failure subject "script-root"
        "a Nix script path needs root = ./.; use a relative string for a generated script"
    else
      let
        root = "${toString spec.root}/";
        path = toString value;
      in
      if lib.hasPrefix root path then
        validation.success (lib.removePrefix root path)
      else
        failure subject "script-path" "script path must be inside root";
  confirmation =
    subject: value:
    if builtins.isBool value then
      validation.success (if value then "Run ${subject}?" else null)
    else if value == null || fields.nonEmpty value then
      validation.success value
    else
      failure subject "confirm" "confirm must be a boolean or non-empty message";
  action =
    subject: autoForward: input:
    let
      raw =
        if builtins.isList input then
          { command = input; }
        else if builtins.isPath input then
          { script = input; }
        else if builtins.isString input then
          { command = input; }
        else
          input;
    in
    validation.andThen (
      s:
      let
        forms = builtins.filter (key: builtins.hasAttr key s) [
          "command"
          "shell"
          "script"
          "prompt"
        ];
        structural = validation.collect [
          (validation.optional (builtins.length forms != 1) (
            diagnostic subject "execution-form" "define exactly one of command, shell, script or prompt"
          ))
          (validation.optional (s ? localFlake && !builtins.isBool s.localFlake) (
            diagnostic subject "local-flake" "localFlake must be a boolean"
          ))
        ];
      in
      validation.andThen (
        _:
        let
          form = builtins.head forms;
          key =
            if form == "shell" then
              "run"
            else if form == "command" && builtins.isList s.command then
              "exec"
            else
              form;
          local = s.localFlake or false;
          args = s.args or [ ];
          targets =
            !local
            || (
              key == "exec"
              && builtins.isList args
              && builtins.all (v: fields.nonEmpty v && !lib.hasPrefix "-" v && !lib.hasInfix "#" v) args
            );
          payload = if form == "script" then script subject s.script else validation.success s.${form};
          confirm = confirmation subject (s.confirm or null);
        in
        validation.andThen
          (
            _:
            validation.map2 (
              value: message:
              removeAttrs s [
                "command"
                "shell"
                "condition"
                "confirm"
                "localFlake"
              ]
              // {
                ${key} = value;
                confirm = message;
                args = if local then map (target: ".#${target}") args else args;
                forwardArgs = s.forwardArgs or (autoForward && form != "prompt");
              }
              // lib.optionalAttrs (form == "script" && builtins.isPath s.script) { rootRelative = true; }
              // lib.optionalAttrs (s ? condition) { when = s.condition; }
            ) payload confirm
          )
          (
            validation.fromDiagnostics (validation.optional (!targets) (
              diagnostic subject "local-flake"
                "localFlake applies only to literal output names in args of an argv command"
            )) null
          )
      ) (validation.fromDiagnostics structural null)
    ) (closed "action" subject (descriptors actionKeys) raw);
  lower =
    name: entry:
    if
      entry.kind == "command"
      && builtins.isList entry.declaration
      && builtins.all builtins.isString entry.declaration
    then
      literal name entry.declaration
    else
      elaborate name entry;
  elaborate =
    name: entry:
    let
      inherit (entry) kind declaration;
      subject = "${kind}s.${name}";
      raw =
        if kind == "task" && builtins.isList declaration then
          { steps = declaration; }
        else if kind == "command" && builtins.isList declaration then
          { command = declaration; }
        else if kind == "command" && builtins.isPath declaration then
          { script = declaration; }
        else
          declaration;
      keys =
        metadata
        ++ [
          "packages"
          "confirm"
        ]
        ++ (if kind == "task" then [ "steps" ] else builtins.filter (key: key != "prompt") actionKeys);
      shape = closed kind subject (descriptors keys) raw;
    in
    validation.andThen (
      s:
      let
        structural =
          if kind == "task" then
            validation.optional (!(s ? steps && builtins.isList s.steps && s.steps != [ ])) (
              diagnostic subject "task-steps" "tasks need a non-empty steps list"
            )
          else
            let
              forms = builtins.filter (key: builtins.hasAttr key s) [
                "command"
                "shell"
                "script"
              ];
            in
            validation.collect [
              (validation.optional (builtins.length forms != 1) (
                diagnostic subject "execution-form" "define exactly one of command, shell or script"
              ))
              (validation.optional (forms == [ "command" ] && !builtins.isList s.command) (
                diagnostic subject "command-argv" "command must be a literal argv list; use shell for shell source"
              ))
            ];
      in
      validation.andThen (
        _:
        let
          steps =
            if kind == "task" then
              validation.sequence (
                lib.imap1 (i: action "${subject}.steps[${toString i}]" (builtins.length s.steps == 1)) s.steps
              )
            else
              validation.map (step: [ step ]) (
                action subject true (
                  builtins.intersectAttrs (descriptors (
                    builtins.filter (
                      key:
                      !(builtins.elem key [
                        "cwd"
                        "env"
                        "timeout"
                        "ui"
                      ])
                    ) actionKeys
                  )) s
                )
              );
          confirmed =
            if kind == "task" then confirmation subject (s.confirm or null) else validation.success null;
        in
        validation.andThen
          (
            value:
            validation.andThen (
              command:
              validation.fromDiagnostics (validation.optional (builtins.elem spec.name command.aliases) (
                diagnostic subject "aliases" "an alias cannot shadow the dispatcher '${spec.name}'"
              )) command
            ) ((if kind == "task" then schema.task else schema.command) name value)
          )
          (
            validation.map2 (
              steps: confirm:
              builtins.intersectAttrs (descriptors metadata) s
              // {
                inherit kind;
                runtimeInputs = s.packages or [ ];
                steps = lib.optional (confirm != null) { prompt.message = confirm; } ++ steps;
              }
            ) steps confirmed
          )
      ) (validation.fromDiagnostics structural null)
    ) shape;
in
lower
