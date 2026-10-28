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
    import ../../src/praxis/compile.nix (
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
    "test single executable inherits arguments" = {
      expr =
        (builtins.head
          (manifestCommand (single {
            steps = [ { exec = [ "cargo" ]; } ];
          })).steps
        ).forwardArgs;
      expected = true;
    };
    "test shell source is never rewritten" = {
      expr = (builtins.head (manifestCommand (single "cargo")).steps).run;
      expected = "cargo";
    };
    "test explicit forwarding opt out" = {
      expr =
        !(builtins.head
          (manifestCommand (single {
            steps = [
              {
                exec = [ "cargo" ];
                forwardArgs = false;
              }
            ];
          })).steps
        ).forwardArgs;
      expected = true;
    };
    "test sequences do not guess a recipient" = {
      expr =
        builtins.all (s: !s.forwardArgs)
          (manifestCommand (single [
            "first"
            "second"
          ])).steps;
      expected = true;
    };
    "test prompt never inherits arguments" = {
      expr =
        !(builtins.head
          (manifestCommand (single {
            steps = [ { prompt.message = "Continue?"; } ];
          })).steps
        ).forwardArgs;
      expected = true;
    };
    "test prompt cannot forward arguments" = {
      expr = rejects "prompt" {
        steps = [
          {
            prompt.message = "Continue?";
            forwardArgs = true;
          }
        ];
      };
      expected = true;
    };
    "test invalid scope keeps body lazy" = {
      expr = rejects "scope" {
        scope = "unknown";
        steps = [ { run = poison; } ];
      };
      expected = true;
    };
    "test scope defaults to project" = {
      expr = (manifestCommand (single "true")).scope;
      expected = "project";
    };
    "test multiline label is not source" = {
      expr = (builtins.head (manifestCommand (single "printf first\nprintf second")).steps).label;
      expected = "gate (step 1)";
    };
    "test choices normalize" = {
      expr =
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
        ).choices;
      expected = [
        "1"
        "2"
      ];
    };
    "test choice default rejected" = {
      expr = rejects "parameter-default" {
        parameters = [
          {
            name = "mode";
            choices = [ "one" ];
            default = "two";
          }
        ];
        steps = [ "true" ];
      };
      expected = true;
    };
    "test choice type rejected" = {
      expr = rejects "parameter-choices" {
        parameters = [
          {
            name = "mode";
            choices = [ 1 ];
          }
        ];
        steps = [ "true" ];
      };
      expected = true;
    };
    "test short collision" = {
      expr = rejects "parameter-short" {
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
      expected = true;
    };
    "test sensitive default not forced" = {
      expr = rejects "parameter-sensitive" {
        parameters = [
          {
            name = "token";
            sensitive = true;
            default = poison;
          }
        ];
        steps = [ "true" ];
      };
      expected = true;
    };
    "test sensitive argv rejected" = {
      expr = rejects "parameter-sensitive" {
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
      expected = true;
    };
    "test invalid group" = {
      expr = rejects "parameter-group" {
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
      expected = true;
    };
    "test invalid condition" = {
      expr = rejects "parameter-reference" {
        steps = [
          {
            run = "true";
            when.parameters.typo = true;
          }
        ];
      };
      expected = true;
    };
    "test invalid timeout" = {
      expr = rejects "timeout" {
        timeout = 0;
        steps = [ "true" ];
      };
      expected = true;
    };
    "test invalid ui" = {
      expr = rejects "ui" {
        ui.output = "mystery";
        steps = [ "true" ];
      };
      expected = true;
    };
    "test typed prompt needs acknowledgement" = {
      expr = rejects "prompt" {
        steps = [
          {
            prompt = {
              type = "acknowledge";
              message = "Type it";
            };
          }
        ];
      };
      expected = true;
    };
    "test select needs valid default" = {
      expr = rejects "prompt" {
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
      expected = true;
    };
    "test optional adapters stay outside core" = {
      expr =
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
      expected = true;
    };
    "test type errors keep all reachable paths" = {
      expr =
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
          }).diagnostics.gate;
      expected = [
        [ 0 ]
        [ 0 ]
        [ 1 ]
        [
          1
          "param"
        ]
      ];
    };
    "test unknown argument field keeps payload lazy" = {
      expr =
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
          }).diagnostics.gate;
      expected = [
        "type"
        "refinement"
      ];
    };
    "test type environment path" = {
      expr =
        (builtins.head
          (single {
            steps = [ "true" ];
            env.VALUE = 1;
          }).diagnostics.gate
        ).context.validation.path;
      expected = [
        "env"
        "VALUE"
      ];
    };
    "test type default path" = {
      expr =
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
        ).context.validation.expected;
      expected = "int";
    };
    "test type defaults normalize" = {
      expr =
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
          })).parameters;
      expected = [
        "true"
        "-2"
        "relative/file"
      ];
    };
    "test invalid type skips default payload" = {
      expr = rejects "parameter-type" {
        steps = [ "true" ];
        parameters = [
          {
            name = "count";
            type = "unknown";
            default = poison;
          }
        ];
      };
      expected = true;
    };
    "test diagnostic summary stays selected" = {
      expr =
        (compile {
          pkgs = poison;
          commands = {
            gate = "true";
            unrelated = poison;
          };
        }).diagnosticSummaries.gate.total;
      expected = 0;
    };
    "test diagnostic summary counts" = {
      expr = (single accumulated).diagnosticSummaries.gate;
      expected = {
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
    };
    "test command becomes app and package" = {
      expr =
        builtins.attrNames simple.apps == [ "gate" ]
        && builtins.attrNames simple.packages == [ "gate" ]
        && simple.apps.gate.type == "app"
        && simple.apps.gate.program == "/praxis/gate/bin/gate"
        && simple.packages.gate.name == "gate"
        && simple.packages.gate.meta.mainProgram == "gate";
      expected = true;
    };
    "test multiple commands compile" = {
      expr =
        builtins.attrNames
          (compile {
            commands = {
              test = inline "true";
              fmt = inline "true";
            };
          }).apps;
      expected = [
        "fmt"
        "test"
      ];
    };
    "test steps keep order" = {
      expr = map (step: step.label) declaration.steps;
      expected = [
        "first"
        "second"
        "third"
      ];
    };
    "test mixed forms compile" = {
      expr = map (step: step.kind) declaration.steps;
      expected = [
        "run"
        "script"
        "run"
      ];
    };
    "test runtime inputs stay lazy" = {
      expr = mixed.diagnostics.gate;
      expected = [ ];
    };
    "test description propagates" = {
      expr =
        (single ((inline "true") // { description = "Project acceptance"; })).apps.gate.meta.description;
      expected = "Project acceptance";
    };
    "test unknown command field" = {
      expr = rejects "command-field" ((inline "true") // { typo = poison; });
      expected = true;
    };
    "test unknown step field" = {
      expr = rejects "step-field" {
        steps = [
          {
            run = "true";
            typo = poison;
          }
        ];
      };
      expected = true;
    };
    "test empty steps" = {
      expr = rejects "steps-shape" { steps = [ ]; };
      expected = true;
    };
    "test absent steps" = {
      expr = rejects "steps-shape" { };
      expected = true;
    };
    "test missing form" = {
      expr = rejects "execution-form" { steps = [ { } ]; };
      expected = true;
    };
    "test both forms" = {
      expr = rejects "execution-form" {
        steps = [
          {
            run = poison;
            script = poison;
          }
        ];
      };
      expected = true;
    };
    "test absolute script" = {
      expr = rejects "script-path" { steps = [ { script = "/tmp/example"; } ]; };
      expected = true;
    };
    "test traversal script" = {
      expr = rejects "script-path" { steps = [ { script = "ci/../example"; } ]; };
      expected = true;
    };
    "test parent script" = {
      expr = rejects "script-path" { steps = [ { script = "../example"; } ]; };
      expected = true;
    };
    "test dot script" = {
      expr = rejects "script-path" { steps = [ { script = "./ci/example"; } ]; };
      expected = true;
    };
    "test empty segment script" = {
      expr = rejects "script-path" { steps = [ { script = "ci//example"; } ]; };
      expected = true;
    };
    "test empty script" = {
      expr = rejects "script-path" { steps = [ { script = ""; } ]; };
      expected = true;
    };
    "test empty run" = {
      expr = rejects "run-shape" (inline "");
      expected = true;
    };
    "test wrong run type" = {
      expr = rejects "run-shape" (inline 7);
      expected = true;
    };
    "test wrong step type" = {
      expr = rejects "step-shape" { steps = [ 7 ]; };
      expected = true;
    };
    "test args must be list" = {
      expr = rejects "args-shape" {
        steps = [
          {
            run = "true";
            args = "--all";
          }
        ];
      };
      expected = true;
    };
    "test args must be strings" = {
      expr = rejects "args-shape" {
        steps = [
          {
            run = "true";
            args = [ 1 ];
          }
        ];
      };
      expected = true;
    };
    "test interpreter requires script" = {
      expr = rejects "interpreter-form" {
        steps = [
          {
            run = "true";
            interpreter = poison;
          }
        ];
      };
      expected = true;
    };
    "test interpreter must be string" = {
      expr = rejects "interpreter-shape" {
        steps = [
          {
            script = "ci/x";
            interpreter = [ "bash" ];
          }
        ];
      };
      expected = true;
    };
    "test empty interpreter" = {
      expr = rejects "interpreter-shape" {
        steps = [
          {
            script = "ci/x";
            interpreter = "";
          }
        ];
      };
      expected = true;
    };
    "test env must be record" = {
      expr = rejects "env-shape" ((inline "true") // { env = [ ]; });
      expected = true;
    };
    "test env name is validated before value" = {
      expr = rejects "env-name" ((inline "true") // { env."A-B" = poison; });
      expected = true;
    };
    "test env values must be strings" = {
      expr = rejects "env-value" ((inline "true") // { env.VALUE = 1; });
      expected = true;
    };
    "test runtime inputs must be list" = {
      expr = rejects "runtime-inputs-shape" ((inline "true") // { runtimeInputs = { }; });
      expected = true;
    };
    "test runtime inputs must be packages" = {
      expr = rejects "runtime-input" ((inline "true") // { runtimeInputs = [ "/bin" ]; });
      expected = true;
    };
    "test empty name rejected before payload" = {
      expr = (compile { commands."" = poison; }).diagnostics."" != [ ];
      expected = true;
    };
    "test unsafe name rejected" = {
      expr = (compile { commands."../gate" = poison; }).diagnostics."../gate" != [ ];
      expected = true;
    };
    "test unknown project field" = {
      expr = throws (compile { typo = poison; }).packages;
      expected = true;
    };
    "test invalid root" = {
      expr = throws (compile { root = "./fixtures"; }).packages;
      expected = true;
    };
    "test missing root marker" = {
      expr = throws (compile { root = ./fixtures/ci; }).packages;
      expected = true;
    };
    "test invalid command map" = {
      expr = throws (compile { commands = [ ]; }).packages;
      expected = true;
    };
    "test invalid command shape" = {
      expr = rejects "command-shape" 7;
      expected = true;
    };
    "test invalid label" = {
      expr = rejects "label-shape" {
        steps = [
          {
            run = "true";
            label = 7;
          }
        ];
      };
      expected = true;
    };
    "test invalid description" = {
      expr = rejects "description-shape" ((inline "true") // { description = 7; });
      expected = true;
    };
    "test path stays literal" = {
      expr = (builtins.elemAt declaration.steps 1).script;
      expected = scriptPath;
    };
    "test arguments stay literal" = {
      expr = (builtins.head declaration.steps).args;
      expected = arguments;
    };
    "test environment stays literal" = {
      expr = declaration.env.TEST;
      expected = envValue;
    };
    "test inline body stays literal" = {
      expr = (builtins.head declaration.steps).run;
      expected = "printf '%s\\n' \"$@\"";
    };
    "test runtime does not cd to store root" = {
      expr = mixed.manifests.gate.project.cwd == null && !mixed.manifests.gate.project.requireRoot;
      expected = true;
    };
    "test no flake needed" = {
      expr =
        (compile {
          root = null;
          commands.gate = "true";
        }).diagnostics.gate;
      expected = [ ];
    };
    "test shorthand string" = {
      expr = (manifestCommand (single "true")).steps;
      expected = (manifestCommand simple).steps;
    };
    "test shorthand list" = {
      expr =
        map (s: s.run)
          (manifestCommand (single [
            "first"
            "second"
          ])).steps;
      expected = [
        "first"
        "second"
      ];
    };
    "test literal exec" = {
      expr =
        (manifestCommand (single [
          {
            exec = [
              "printf"
              "a b"
              ""
            ];
          }
        ])).steps != [ ];
      expected = true;
    };
    "test empty exec" = {
      expr = rejects "exec-shape" { steps = [ { exec = [ ]; } ]; };
      expected = true;
    };
    "test wrong exec" = {
      expr = rejects "exec-shape" { steps = [ { exec = "echo"; } ]; };
      expected = true;
    };
    "test invalid command reference" = {
      expr = rejects "command-shape" { steps = [ { command = 1; } ]; };
      expected = true;
    };
    "test missing reference" = {
      expr = rejects "command-reference" { steps = [ { command = "missing"; } ]; };
      expected = true;
    };
    "test cycle rejected" = {
      expr =
        (compile {
          commands = {
            a = [ { command = "b"; } ];
            b = [ { command = "a"; } ];
          };
        }).diagnostics.a != [ ];
      expected = true;
    };
    "test reachable only" = {
      expr =
        builtins.attrNames
          (compile {
            commands = {
              gate = [ { command = "child"; } ];
              child = "true";
              bad = poison;
            };
          }).manifests.gate.commands;
      expected = [
        "child"
        "gate"
      ];
    };
    "test unknown parameter reference" = {
      expr = rejects "parameter-reference" {
        steps = [
          {
            exec = [
              "printf"
              { param = "missing"; }
            ];
          }
        ];
      };
      expected = true;
    };
    "test multiple forwarders" = {
      expr = rejects "forward-args" {
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
      expected = true;
    };
    "test typed default" = {
      expr =
        (manifestCommand (single {
          parameters = [
            {
              name = "count";
              type = "int";
              default = 3;
            }
          ];
          steps = [ "true" ];
        })).parameters;
      expected = [
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
    };
    "test duplicate parameter" = {
      expr = rejects "parameter-name" {
        parameters = [
          { name = "host"; }
          { name = "HOST"; }
        ];
        steps = [ "true" ];
      };
      expected = true;
    };
    "test bad default" = {
      expr = rejects "parameter-default" {
        parameters = [
          {
            name = "count";
            type = "int";
            default = "three";
          }
        ];
        steps = [ "true" ];
      };
      expected = true;
    };
    "test optional before required" = {
      expr = rejects "parameter-order" {
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
      expected = true;
    };
    "test named parameters do not change positional order" = {
      expr =
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
        }).diagnostics.gate;
      expected = [ ];
    };
    "test separated required positional is rejected" = {
      expr = rejects "parameter-order" {
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
      expected = true;
    };
    "test parameter reference is case sensitive" = {
      expr = rejects "parameter-reference" {
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
      expected = true;
    };
    "test parameter environment collision" = {
      expr = rejects "parameter-name" {
        parameters = [
          { name = "two-words"; }
          { name = "TWO-WORDS"; }
        ];
        steps = [ "true" ];
      };
      expected = true;
    };
    "test parameter condition types must match" = {
      expr = rejects "condition" {
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
      expected = true;
    };
    "test parameter conditions must use choices" = {
      expr = rejects "condition" {
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
      expected = true;
    };
    "test typed parameter conditions are valid" = {
      expr =
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
        }).diagnostics.gate;
      expected = [ ];
    };
    "test reachable aliases cannot collide" = {
      expr =
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
      expected = true;
    };
    "test selected alias check keeps siblings lazy" = {
      expr =
        (compile {
          commands = {
            gate = {
              aliases = [ "g" ];
              steps = [ "true" ];
            };
            unrelated = poison;
          };
        }).diagnostics.gate;
      expected = [ ];
    };
    "test sensitive sources cannot feed referenced defaults" = {
      expr =
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
      expected = true;
    };
    "test sensitive keys cannot be overridden in references" = {
      expr =
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
      expected = true;
    };
    "test sensitive sources cannot replace prompt results" = {
      expr = rejects "parameter-sensitive" {
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
      expected = true;
    };
    "test shared reference diagnostics stay ordered" = {
      expr =
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
          }).diagnostics.gate;
      expected = [
        "praxis/command-reference"
        "praxis/steps-shape"
      ];
    };
    "test all three layouts have the same manifest" = {
      expr = import ./layouts.nix {
        praxis = compile;
        pkgs = pkgs // {
          bash = {
            type = "derivation";
            outPath = "/bash";
          };
        };
      };
      expected = true;
    };
    "test root policy conflict" = {
      expr =
        throws
          (compile {
            cwd = "/tmp";
            discoverRoot = "flake.nix";
          }).packages;
      expected = true;
    };
    "test missing live script is not an eval error" = {
      expr = (single { steps = [ { script = "ci/generated-later"; } ]; }).diagnostics.gate;
      expected = [ ];
    };
    "test diagnostics accumulate" = {
      expr = codes accumulated;
      expected = [
        "praxis/runtime-input"
        "praxis/env-name"
        "praxis/env-value"
        "praxis/execution-form"
        "praxis/execution-form"
        "praxis/script-path"
        "praxis/args-shape"
        "praxis/args-shape"
      ];
    };
    "test malformed command does not force sibling" = {
      expr = malformed.diagnostics.broken != [ ];
      expected = true;
    };
    "test valid command does not force sibling" = {
      expr =
        independent.apps.gate.program == "/praxis/gate/bin/gate"
        && builtins.isString independent.packages.gate.text;
      expected = true;
    };
    "test command names do not force declarations" = {
      expr = builtins.attrNames independent.packages;
      expected = [
        "broken"
        "gate"
      ];
    };
    "test diagnostics do not force builders" = {
      expr =
        (compile {
          pkgs = poison;
          commands.gate = (inline "echo never executed during evaluation") // {
            runtimeInputs = [ package ];
          };
        }).diagnostics.gate;
      expected = [ ];
    };
    "test structural error does not force body" = {
      expr = rejects "command-field" {
        steps = [ { run = poison; } ];
        typo = poison;
      };
      expected = true;
    };
    "test empty declaration is no op" = {
      expr = empty.apps == { } && empty.packages == { } && empty.diagnostics == { };
      expected = true;
    };
    "test selected invalid command throws" = {
      expr = throws (single { steps = [ ]; }).apps.gate;
      expected = true;
    };
    "test rendered diagnostics stay praxis owned" = {
      expr = builtins.all (
        diagnostic:
        lib.hasInfix "[praxis/" (krisis.renderPlain diagnostic)
        && !(lib.hasInfix "axiom:" (krisis.renderPlain diagnostic))
      ) (single accumulated).diagnostics.gate;
      expected = true;
    };
    "test output is deterministic" = {
      expr =
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
        }).packages.gate.text;
      expected =
        (compile {
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
  };
  failing = builtins.attrNames (lib.filterAttrs (_: value: !value) tests);
  ok =
    if failing == [ ] then true else throw "praxis tests failed: ${lib.concatStringsSep ", " failing}";
}
