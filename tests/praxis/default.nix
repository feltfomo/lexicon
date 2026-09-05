{
  lib,
  axiom,
  krisis,
}:
let
  poison = throw "praxis forced an unrelated payload";
  pkgs = {
    bash = "/bash";
    writeText = _: text: "/manifest-${builtins.hashString "sha256" text}";
    rustPlatform.buildRustPackage = _: "/runner";
    writeShellApplication = args: args // { outPath = "/praxis/${args.name}"; };
  };
  compile =
    args:
    import ../../src/praxis.nix (
      {
        inherit
          lib
          axiom
          krisis
          pkgs
          ;
        root = ./fixtures;
      }
      // args
    );
  inline = run: { steps = [ { inherit run; } ]; };
  single = spec: compile { commands.gate = spec; };
  codes = spec: map (diagnostic: diagnostic.code) (single spec).diagnostics.gate;
  rejects = code: spec: builtins.elem "praxis/${code}" (codes spec);
  throws = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  manifestCommand = value: value.manifests.gate.commands.gate;
  simple = single (inline "true");
  package = {
    type = "derivation";
    outPath = poison;
    drvPath = poison;
  };
  scriptPath = "ci/record 'args'.sh";
  arguments = [
    "a b"
    "'quote'"
    "$(touch injected)"
    ""
    "-n"
    "line\nbreak"
    "a\\b"
  ];
  envValue = "value ' $(touch env-injected)\nnext";
  mixed = single {
    runtimeInputs = [ package ];
    env.TEST = envValue;
    steps = [
      {
        run = "printf '%s\\n' \"$@\"";
        label = "first";
        args = arguments;
      }
      {
        script = scriptPath;
        interpreter = "bash";
        label = "second";
        args = arguments;
      }
      {
        run = "true";
        label = "third";
      }
    ];
  };
  independent = compile {
    commands = {
      gate = inline "true";
      broken = poison;
    };
  };
  malformed = compile {
    pkgs = poison;
    commands = {
      broken.steps = [ ];
      unused = poison;
    };
  };
  empty = compile {
    pkgs = poison;
    commands = { };
  };
  accumulated = {
    runtimeInputs = [ 42 ];
    env = {
      "BAD-NAME" = poison;
      VALUE = 13;
    };
    steps = [
      { }
      {
        run = poison;
        script = poison;
      }
      { script = "ci/../outside"; }
      {
        run = "true";
        args = [ 1 ];
      }
    ];
  };
  declaration = manifestCommand mixed;
in
rec {
  tests = {
    multiline-label-is-not-source =
      (builtins.head (manifestCommand (single "printf first\nprintf second")).steps).label
      == "gate (step 1)";
    choices-normalize =
      (builtins.head
        (manifestCommand (single {
          parameters = [
            {
              name = "count";
              type = "int";
              choices = [
                1
                2
              ];
              default = 2;
              short = "c";
              env = "COUNT";
            }
          ];
          steps = [ "true" ];
        })).parameters
      ).choices == [
        "1"
        "2"
      ];
    choice-default-rejected = rejects "parameter-default" {
      parameters = [
        {
          name = "mode";
          choices = [ "one" ];
          default = "two";
        }
      ];
      steps = [ "true" ];
    };
    choice-type-rejected = rejects "parameter-choices" {
      parameters = [
        {
          name = "mode";
          choices = [ 1 ];
        }
      ];
      steps = [ "true" ];
    };
    short-collision = rejects "parameter-short" {
      parameters = [
        {
          name = "one";
          short = "o";
        }
        {
          name = "two";
          short = "o";
        }
      ];
      steps = [ "true" ];
    };
    sensitive-default-not-forced = rejects "parameter-sensitive" {
      parameters = [
        {
          name = "token";
          sensitive = true;
          default = poison;
        }
      ];
      steps = [ "true" ];
    };
    sensitive-argv-rejected = rejects "parameter-sensitive" {
      parameters = [
        {
          name = "token";
          sensitive = true;
        }
      ];
      steps = [
        {
          exec = [
            "true"
            { param = "token"; }
          ];
        }
      ];
    };
    invalid-group = rejects "parameter-group" {
      parameters = [ { name = "one"; } ];
      parameterGroups = [
        {
          type = "exclusive";
          parameters = [
            "one"
            "missing"
          ];
        }
      ];
      steps = [ "true" ];
    };
    invalid-condition = rejects "parameter-reference" {
      steps = [
        {
          run = "true";
          when.parameters.typo = true;
        }
      ];
    };
    invalid-timeout = rejects "timeout" {
      timeout = 0;
      steps = [ "true" ];
    };
    invalid-ui = rejects "ui" {
      ui.output = "mystery";
      steps = [ "true" ];
    };
    typed-prompt-needs-acknowledgement = rejects "prompt" {
      steps = [
        {
          prompt = {
            type = "acknowledge";
            message = "Type it";
          };
        }
      ];
    };
    select-needs-valid-default = rejects "prompt" {
      steps = [
        {
          prompt = {
            type = "select";
            message = "Choose";
            name = "choice";
            choices = [ "a" ];
            default = "b";
          };
        }
      ];
    };
    optional-adapters-stay-outside-core =
      let
        adapters = import ../../src/praxis/adapters.nix { inherit lib; };
      in
      (adapters.fromDen {
        roster = {
          hosts = [
            "x86_64-linux/b"
            "aarch64-linux/a"
          ];
          users = [ "person" ];
        };
        unrelated = poison;
      }).host.choices == [
        "aarch64-linux/a"
        "x86_64-linux/b"
      ];
    type-errors-keep-all-reachable-paths =
      map (d: d.context.validation.path)
        (single {
          steps = [
            {
              run = "true";
              args = [
                1
                { param = false; }
              ];
            }
          ];
        }).diagnostics.gate == [
        [ 0 ]
        [ 0 ]
        [ 1 ]
        [
          1
          "param"
        ]
      ];
    unknown-argument-field-keeps-payload-lazy =
      map (d: d.context.validation.reason)
        (single {
          steps = [
            {
              run = "true";
              args = [
                {
                  param = poison;
                  secret = poison;
                }
              ];
            }
          ];
        }).diagnostics.gate == [
        "type"
        "refinement"
      ];
    type-environment-path =
      (builtins.head
        (single {
          steps = [ "true" ];
          env.VALUE = 1;
        }).diagnostics.gate
      ).context.validation.path == [
        "env"
        "VALUE"
      ];
    type-default-path =
      (builtins.head
        (single {
          steps = [ "true" ];
          parameters = [
            {
              name = "count";
              type = "int";
              default = "three";
            }
          ];
        }).diagnostics.gate
      ).context.validation.expected == "int";
    type-defaults-normalize =
      map (p: p.default)
        (manifestCommand (single {
          steps = [ "true" ];
          parameters = [
            {
              name = "enabled";
              type = "bool";
              default = true;
            }
            {
              name = "count";
              type = "int";
              default = -2;
            }
            {
              name = "location";
              type = "path";
              default = "relative/file";
            }
          ];
        })).parameters == [
        "true"
        "-2"
        "relative/file"
      ];
    invalid-type-skips-default-payload = rejects "parameter-type" {
      steps = [ "true" ];
      parameters = [
        {
          name = "count";
          type = "unknown";
          default = poison;
        }
      ];
    };
    diagnostic-summary-stays-selected =
      (compile {
        pkgs = poison;
        commands = {
          gate = "true";
          unrelated = poison;
        };
      }).diagnosticSummaries.gate.total == 0;
    diagnostic-summary-counts =
      (single accumulated).diagnosticSummaries.gate == {
        total = 8;
        hasErrors = true;
        bySeverity = {
          error = 8;
          warning = 0;
          info = 0;
        };
        byCode = {
          "praxis/runtime-input" = 1;
          "praxis/env-name" = 1;
          "praxis/env-value" = 1;
          "praxis/execution-form" = 2;
          "praxis/script-path" = 1;
          "praxis/args-shape" = 2;
        };
      };
    command-becomes-app-and-package =
      builtins.attrNames simple.apps == [ "gate" ]
      && builtins.attrNames simple.packages == [ "gate" ]
      && simple.apps.gate.type == "app"
      && simple.apps.gate.program == "/praxis/gate/bin/gate"
      && simple.packages.gate.name == "gate"
      && simple.packages.gate.meta.mainProgram == "gate";
    multiple-commands-compile =
      builtins.attrNames
        (compile {
          commands = {
            test = inline "true";
            fmt = inline "true";
          };
        }).apps == [
        "fmt"
        "test"
      ];
    steps-keep-order =
      map (step: step.label) declaration.steps == [
        "first"
        "second"
        "third"
      ];
    mixed-forms-compile =
      map (step: step.kind) declaration.steps == [
        "run"
        "script"
        "run"
      ];
    runtime-inputs-stay-lazy = mixed.diagnostics.gate == [ ];
    description-propagates =
      (single ((inline "true") // { description = "Project acceptance"; })).apps.gate.meta.description
      == "Project acceptance";
    unknown-command-field = rejects "command-field" ((inline "true") // { typo = poison; });
    unknown-step-field = rejects "step-field" {
      steps = [
        {
          run = "true";
          typo = poison;
        }
      ];
    };
    empty-steps = rejects "steps-shape" { steps = [ ]; };
    absent-steps = rejects "steps-shape" { };
    missing-form = rejects "execution-form" { steps = [ { } ]; };
    both-forms = rejects "execution-form" {
      steps = [
        {
          run = poison;
          script = poison;
        }
      ];
    };
    absolute-script = rejects "script-path" { steps = [ { script = "/tmp/example"; } ]; };
    traversal-script = rejects "script-path" { steps = [ { script = "ci/../example"; } ]; };
    parent-script = rejects "script-path" { steps = [ { script = "../example"; } ]; };
    dot-script = rejects "script-path" { steps = [ { script = "./ci/example"; } ]; };
    empty-segment-script = rejects "script-path" { steps = [ { script = "ci//example"; } ]; };
    empty-script = rejects "script-path" { steps = [ { script = ""; } ]; };
    empty-run = rejects "run-shape" (inline "");
    wrong-run-type = rejects "run-shape" (inline 7);
    wrong-step-type = rejects "step-shape" { steps = [ 7 ]; };
    args-must-be-list = rejects "args-shape" {
      steps = [
        {
          run = "true";
          args = "--all";
        }
      ];
    };
    args-must-be-strings = rejects "args-shape" {
      steps = [
        {
          run = "true";
          args = [ 1 ];
        }
      ];
    };
    interpreter-requires-script = rejects "interpreter-form" {
      steps = [
        {
          run = "true";
          interpreter = poison;
        }
      ];
    };
    interpreter-must-be-string = rejects "interpreter-shape" {
      steps = [
        {
          script = "ci/x";
          interpreter = [ "bash" ];
        }
      ];
    };
    empty-interpreter = rejects "interpreter-shape" {
      steps = [
        {
          script = "ci/x";
          interpreter = "";
        }
      ];
    };
    env-must-be-record = rejects "env-shape" ((inline "true") // { env = [ ]; });
    env-name-is-validated-before-value = rejects "env-name" (
      (inline "true") // { env."A-B" = poison; }
    );
    env-values-must-be-strings = rejects "env-value" ((inline "true") // { env.VALUE = 1; });
    runtime-inputs-must-be-list = rejects "runtime-inputs-shape" (
      (inline "true") // { runtimeInputs = { }; }
    );
    runtime-inputs-must-be-packages = rejects "runtime-input" (
      (inline "true") // { runtimeInputs = [ "/bin" ]; }
    );
    empty-name-rejected-before-payload = (compile { commands."" = poison; }).diagnostics."" != [ ];
    unsafe-name-rejected = (compile { commands."../gate" = poison; }).diagnostics."../gate" != [ ];
    unknown-project-field = throws (compile { typo = poison; }).packages;
    invalid-root = throws (compile { root = "./fixtures"; }).packages;
    missing-root-marker = throws (compile { root = ./fixtures/ci; }).packages;
    invalid-command-map = throws (compile { commands = [ ]; }).packages;
    invalid-command-shape = rejects "command-shape" 7;
    invalid-label = rejects "label-shape" {
      steps = [
        {
          run = "true";
          label = 7;
        }
      ];
    };
    invalid-description = rejects "description-shape" ((inline "true") // { description = 7; });
    path-stays-literal = (builtins.elemAt declaration.steps 1).script == scriptPath;
    arguments-stay-literal = (builtins.head declaration.steps).args == arguments;
    environment-stays-literal = declaration.env.TEST == envValue;
    inline-body-stays-literal = (builtins.head declaration.steps).run == "printf '%s\\n' \"$@\"";
    runtime-does-not-cd-to-store-root =
      mixed.manifests.gate.project.cwd == null && !mixed.manifests.gate.project.requireRoot;
    no-flake-needed =
      (compile {
        root = null;
        commands.gate = "true";
      }).diagnostics.gate == [ ];
    shorthand-string = (manifestCommand (single "true")).steps == (manifestCommand simple).steps;
    shorthand-list =
      map (s: s.run)
        (manifestCommand (single [
          "first"
          "second"
        ])).steps == [
        "first"
        "second"
      ];
    literal-exec =
      (manifestCommand (single [
        {
          exec = [
            "printf"
            "a b"
            ""
          ];
        }
      ])).steps != [ ];
    empty-exec = rejects "exec-shape" { steps = [ { exec = [ ]; } ]; };
    wrong-exec = rejects "exec-shape" { steps = [ { exec = "echo"; } ]; };
    invalid-command-reference = rejects "command-shape" { steps = [ { command = 1; } ]; };
    missing-reference = rejects "command-reference" { steps = [ { command = "missing"; } ]; };
    cycle-rejected =
      (compile {
        commands = {
          a = [ { command = "b"; } ];
          b = [ { command = "a"; } ];
        };
      }).diagnostics.a != [ ];
    reachable-only =
      builtins.attrNames
        (compile {
          commands = {
            gate = [ { command = "child"; } ];
            child = "true";
            bad = poison;
          };
        }).manifests.gate.commands == [
        "child"
        "gate"
      ];
    unknown-parameter-reference = rejects "parameter-reference" {
      steps = [
        {
          exec = [
            "printf"
            { param = "missing"; }
          ];
        }
      ];
    };
    multiple-forwarders = rejects "forward-args" {
      steps = [
        {
          run = "true";
          forwardArgs = true;
        }
        {
          run = "true";
          forwardArgs = true;
        }
      ];
    };
    typed-default =
      (manifestCommand (single {
        parameters = [
          {
            name = "count";
            type = "int";
            default = 3;
          }
        ];
        steps = [ "true" ];
      })).parameters == [
        {
          name = "count";
          type = "int";
          default = "3";
          required = false;
          positional = false;
          description = "";
          choices = [ ];
          env = null;
          short = null;
          sensitive = false;
        }
      ];
    duplicate-parameter = rejects "parameter-name" {
      parameters = [
        { name = "host"; }
        { name = "HOST"; }
      ];
      steps = [ "true" ];
    };
    bad-default = rejects "parameter-default" {
      parameters = [
        {
          name = "count";
          type = "int";
          default = "three";
        }
      ];
      steps = [ "true" ];
    };
    optional-before-required = rejects "parameter-order" {
      parameters = [
        {
          name = "first";
          positional = true;
        }
        {
          name = "second";
          positional = true;
          required = true;
        }
      ];
      steps = [ "true" ];
    };
    named-parameters-do-not-change-positional-order =
      (single {
        parameters = [
          { name = "flag"; }
          {
            name = "first";
            positional = true;
            required = true;
          }
          { name = "other"; }
          {
            name = "second";
            positional = true;
            required = true;
          }
          {
            name = "last";
            positional = true;
          }
        ];
        steps = [ "true" ];
      }).diagnostics.gate == [ ];
    separated-required-positional-is-rejected = rejects "parameter-order" {
      parameters = [
        {
          name = "optional";
          positional = true;
        }
        {
          name = "named";
          required = true;
        }
        {
          name = "required";
          positional = true;
          required = true;
        }
      ];
      steps = [ "true" ];
    };
    parameter-reference-is-case-sensitive = rejects "parameter-reference" {
      parameters = [ { name = "host"; } ];
      steps = [
        {
          exec = [
            "true"
            { param = "HOST"; }
          ];
        }
      ];
    };
    parameter-environment-collision = rejects "parameter-name" {
      parameters = [
        { name = "two-words"; }
        { name = "TWO-WORDS"; }
      ];
      steps = [ "true" ];
    };
    parameter-condition-types-must-match = rejects "condition" {
      parameters = [
        {
          name = "enabled";
          type = "bool";
        }
      ];
      steps = [
        {
          run = "true";
          when.parameters.enabled = "true";
        }
      ];
    };
    parameter-conditions-must-use-choices = rejects "condition" {
      parameters = [
        {
          name = "mode";
          choices = [
            "debug"
            "release"
          ];
        }
      ];
      steps = [
        {
          run = "true";
          when.parameters.mode = "other";
        }
      ];
    };
    typed-parameter-conditions-are-valid =
      (single {
        parameters = [
          {
            name = "count";
            type = "int";
            choices = [ 2 ];
            default = 2;
          }
        ];
        steps = [
          {
            run = "true";
            when.parameters.count = 2;
          }
        ];
      }).diagnostics.gate == [ ];
    reachable-aliases-cannot-collide =
      builtins.any (d: d.code == "praxis/aliases")
        (compile {
          commands = {
            gate = [
              { command = "a"; }
              { command = "b"; }
            ];
            a = {
              aliases = [ "both" ];
              steps = [ "true" ];
            };
            b = {
              aliases = [ "both" ];
              steps = [ "true" ];
            };
            unrelated = poison;
          };
        }).diagnostics.gate;
    selected-alias-check-keeps-siblings-lazy =
      (compile {
        commands = {
          gate = {
            aliases = [ "g" ];
            steps = [ "true" ];
          };
          unrelated = poison;
        };
      }).diagnostics.gate == [ ];
    sensitive-sources-cannot-feed-referenced-defaults =
      builtins.any (d: d.code == "praxis/parameter-sensitive")
        (compile {
          commands = {
            gate = {
              parameters = [
                {
                  name = "token";
                  sensitive = true;
                  env = "DEPLOY_TOKEN";
                }
              ];
              steps = [ { command = "child"; } ];
            };
            child = {
              parameters = [
                {
                  name = "ordinary";
                  env = "DEPLOY_TOKEN";
                }
              ];
              steps = [ "true" ];
            };
          };
        }).diagnostics.gate;
    sensitive-keys-cannot-be-overridden-in-references =
      builtins.any (d: d.code == "praxis/parameter-sensitive")
        (compile {
          commands = {
            gate = {
              parameters = [
                {
                  name = "token";
                  sensitive = true;
                }
              ];
              steps = [ { command = "child"; } ];
            };
            child = {
              env.PRAXIS_ARG_TOKEN = "not-a-secret";
              steps = [ "true" ];
            };
          };
        }).diagnostics.gate;
    sensitive-sources-cannot-replace-prompt-results = rejects "parameter-sensitive" {
      parameters = [
        {
          name = "token";
          sensitive = true;
          env = "PRAXIS_PROMPT_TARGET";
        }
      ];
      steps = [
        {
          prompt = {
            type = "select";
            message = "Target";
            name = "target";
            choices = [ "local" ];
          };
        }
      ];
    };
    shared-reference-diagnostics-stay-ordered =
      map (diagnostic: diagnostic.code)
        (compile {
          commands = {
            gate = [
              { command = "a"; }
              { command = "b"; }
              { command = "a"; }
            ];
            a = [ { command = "missing"; } ];
            b.steps = [ ];
            unrelated = poison;
          };
        }).diagnostics.gate == [
        "praxis/command-reference"
        "praxis/steps-shape"
      ];
    large-parameter-set-stays-builder-free =
      import ./benchmark.nix {
        praxis = compile;
        count = 256;
      } == 256;
    all-three-layouts-have-the-same-manifest = import ./layouts.nix {
      praxis = compile;
      pkgs = pkgs // {
        bash = {
          type = "derivation";
          outPath = "/bash";
        };
      };
    };
    root-policy-conflict =
      throws
        (compile {
          cwd = "/tmp";
          discoverRoot = "flake.nix";
        }).packages;
    missing-live-script-is-not-an-eval-error =
      (single { steps = [ { script = "ci/generated-later"; } ]; }).diagnostics.gate == [ ];
    diagnostics-accumulate =
      codes accumulated == [
        "praxis/runtime-input"
        "praxis/env-name"
        "praxis/env-value"
        "praxis/execution-form"
        "praxis/execution-form"
        "praxis/script-path"
        "praxis/args-shape"
        "praxis/args-shape"
      ];
    malformed-command-does-not-force-sibling = malformed.diagnostics.broken != [ ];
    valid-command-does-not-force-sibling =
      independent.apps.gate.program == "/praxis/gate/bin/gate"
      && builtins.isString independent.packages.gate.text;
    command-names-do-not-force-declarations =
      builtins.attrNames independent.packages == [
        "broken"
        "gate"
      ];
    diagnostics-do-not-force-builders =
      (compile {
        pkgs = poison;
        commands.gate = (inline "echo never executed during evaluation") // {
          runtimeInputs = [ package ];
        };
      }).diagnostics.gate == [ ];
    structural-error-does-not-force-body = rejects "command-field" {
      steps = [ { run = poison; } ];
      typo = poison;
    };
    empty-declaration-is-no-op = empty.apps == { } && empty.packages == { } && empty.diagnostics == { };
    selected-invalid-command-throws = throws (single { steps = [ ]; }).apps.gate;
    rendered-diagnostics-stay-praxis-owned = builtins.all (
      diagnostic:
      lib.hasInfix "[praxis/" (krisis.renderPlain diagnostic)
      && !(lib.hasInfix "axiom:" (krisis.renderPlain diagnostic))
    ) (single accumulated).diagnostics.gate;
    output-is-deterministic =
      (compile {
        commands = {
          z = inline "true";
          gate = (inline "true") // {
            env = {
              B = "2";
              A = "1";
            };
          };
        };
      }).packages.gate.text == (compile {
        commands = {
          gate = (inline "true") // {
            env = {
              A = "1";
              B = "2";
            };
          };
          z = poison;
        };
      }).packages.gate.text;
  };
  failing = builtins.attrNames (lib.filterAttrs (_: value: !value) tests);
  ok =
    if failing == [ ] then true else throw "praxis tests failed: ${lib.concatStringsSep ", " failing}";
}
