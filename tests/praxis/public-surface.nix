{
  lib,
  axiom,
  krisis,
}:
let
  poison = throw "praxis public surface forced an inactive payload";
  pkgs = rec {
    bash = "/bash";
    nix = "/nix";
    stdenv.hostPlatform.system = "x86_64-linux";
    rustPlatform.buildRustPackage = _: "/runner";
    writeText = _: text: "/manifest-${builtins.hashString "sha256" text}";
    writeShellApplication = a: a // { outPath = "/packages/${a.name}"; };
    symlinkJoin = a: a // { outPath = "/packages/${a.name}"; };
    mkShell = a: a;
    runCommand = name: _: text: {
      inherit name text;
      type = "derivation";
      outPath = "/checks/${name}";
    };
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
      }
      // args
    );
  one = value: compile { commands.tool = value; };
  manifest = result: result.manifests.tool.commands.tool;
  rejected = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  codes = value: map (d: d.code) (one value).diagnostics.tool;
  literal = [
    "printf"
    "two words"
    ""
    "\n"
    "$(touch never)"
    "--help"
  ];
  problem = krisis.mkDiagnosticFactory {
    severity = "error";
    codePrefix = "praxis";
  };
  fields = import ../../src/praxis/fields.nix {
    inherit
      lib
      axiom
      krisis
      problem
      ;
  };
  primitive = import ../../src/praxis/normalize.nix {
    inherit
      lib
      axiom
      krisis
      problem
      fields
      ;
    spec = poison;
    schema = poison;
  };
  own = import ../../src/ownerships { inherit lib axiom krisis; };
  roster = own.toRoster [
    (own.define.host "desk" { system = "x86_64-linux"; })
    (own.define.host "away" { system = "aarch64-linux"; })
    (own.define.user "alex" { hosts = [ "desk" ]; })
    (own.define.user "sam" { hosts = [ "away" ]; })
  ];
  ownership = host: {
    inherit roster;
    scope = "system";
    context.host.id = host;
  };
  selected =
    host:
    compile {
      ownership = ownership host;
      commands = {
        global = [ "true" ];
        desk = {
          hosts = [ "desk" ];
          command = [ "true" ];
        };
        away = {
          hosts = [ "away" ];
          command = [ "false" ];
        };
        excluded = {
          exceptHosts = [ "away" ];
          shell = "true";
        };
        predicate = {
          when = ctx: ctx.host.id == "x86_64-linux/desk";
          command = [ "true" ];
        };
      };
      tasks.once = {
        hosts = [ "desk" ];
        steps = [ "desk" ];
      };
    };
  guarded =
    check:
    compile {
      commands.tool = check;
      checks = [ "tool" ];
    };
  availabilityProbe =
    (compile {
      ownership = ownership "x86_64-linux/desk";
      commands.tool = {
        hosts = [ "desk" ];
        command = poison;
        parameters = poison;
        packages = poison;
        ui = poison;
      };
      commands.unavailable = {
        hosts = [ "away" ];
        script = poison;
      };
      tasks.unavailable = {
        hosts = [ "away" ];
        steps = poison;
      };
    }).availability;
  tests = {
    "test project scope is inherited" = {
      expr =
        let
          result = compile {
            scope = "global";
            commands.tool = literal;
            commands.local = {
              command = literal;
              scope = "project";
            };
            tasks.once = [ "tool" ];
          };
        in
        result.manifest.commands.tool.scope == "global"
        && result.manifest.commands.once.scope == "global"
        && result.manifest.commands.local.scope == "project";
      expected = true;
    };
    "test positional order and defaults" = {
      expr =
        let
          inherit
            (
              (manifest (one {
                command = literal;
                positional = [
                  "z"
                  "a"
                ];
                parameters = {
                  a.default = "fallback";
                  z = { };
                  flag.type = "bool";
                };
              }))
            )
            parameters
            ;
        in
        map (p: p.name) parameters == [
          "z"
          "a"
          "flag"
        ]
        &&
          map (p: p.required) parameters == [
            true
            false
            false
          ];
      expected = true;
    };
    "test parameter lists are not public" = {
      expr = builtins.elem "praxis/parameters" (codes {
        command = literal;
        parameters = [ poison ];
      });
      expected = true;
    };
    "test positional typos are rejected" = {
      expr = builtins.elem "praxis/positional" (codes {
        command = literal;
        positional = [ "hosst" ];
        parameters.host = { };
      });
      expected = true;
    };
    "test parameter fields stay lazy on error" = {
      expr = builtins.elem "praxis/parameter-field" (codes {
        command = literal;
        parameters.host = {
          typo = poison;
          choices = poison;
        };
      });
      expected = true;
    };
    "test nested selection keeps siblings lazy" = {
      expr =
        let
          result = compile {
            commands.tools.good = literal;
            commands.tools.unused = poison;
            commands.unrelated = poison;
            tasks.once = [ "tools.good" ];
          };
        in
        builtins.attrNames result.manifests.once.commands == [
          "once"
          "tools.good"
        ];
      expected = true;
    };
    "test namespace manifest has leaves" = {
      expr =
        let
          result = compile {
            commands.update.input = literal;
            commands.update.all = literal;
          };
        in
        builtins.attrNames result.manifests.update.commands == [
          "update.all"
          "update.input"
        ]
        && result.availability.names == [ "update" ];
      expected = true;
    };
    "test invalid namespace name keeps body lazy" = {
      expr =
        let
          result = compile { commands.update."bad name" = poison; };
        in
        builtins.elem "praxis/command-name" (map (d: d.code) result.diagnostics.update);
      expected = true;
    };
    "test namespace task reference is rejected" = {
      expr =
        let
          result = compile {
            commands.update.input = literal;
            tasks.once = [ "update" ];
          };
        in
        builtins.elem "praxis/command-reference" (map (d: d.code) result.diagnostics.once);
      expected = true;
    };
    "test literal argv" = {
      expr = (builtins.head (manifest (one literal)).steps).exec;
      expected = literal;
    };
    "test typo help without payload evaluation" = {
      expr = lib.hasInfix "use 'command'" (
        builtins.toJSON
          (one {
            command = poison;
            commnad = poison;
          }).diagnostics.tool
      );
      expected = true;
    };
    "test manifest order is deterministic" = {
      expr =
        builtins.toJSON
          (compile {
            commands = {
              z = [ "false" ];
              a = literal;
            };
            tasks.once = [
              "a"
              "z"
            ];
          }).manifest;
      expected =
        builtins.toJSON
          (compile {
            tasks.once = [
              "a"
              "z"
            ];
            commands = {
              a = literal;
              z = [ "false" ];
            };
          }).manifest;
    };
    "test availability matrix does not normalize bodies" = {
      expr =
        let
          text = builtins.toJSON availabilityProbe.matrix;
        in
        lib.hasInfix "commands.tool" text
        && lib.hasInfix "commands.unavailable" text
        && lib.hasInfix "x86_64-linux/desk" text
        && lib.hasInfix "aarch64-linux/away" text;
      expected = true;
    };
    "test availability trace keeps bodies lazy" = {
      expr = map (entry: entry.name) availabilityProbe.trace.value.entries;
      expected = [ "tool" ];
    };
    "test inline and imported declarations match" = {
      expr =
        (compile {
          root = ./fixtures;
          atRoot = true;
          commands = {
            tool = [
              "printf"
              "literal"
            ];
            script = {
              script = ./fixtures/ci/fail.sh;
              interpreter = "${pkgs.bash}/bin/bash";
            };
          };
          tasks.gate = [
            "tool"
            "script"
          ];
        }).manifest;
      expected = (compile (import ./fixtures/public-surface.nix { inherit pkgs; })).manifest;
    };
    "test default forwarding" = {
      expr = (builtins.head (manifest (one literal)).steps).forwardArgs;
      expected = true;
    };
    "test optional metadata" = {
      expr = (manifest (one literal)).description;
      expected = "";
    };
    "test primitive never forces optional machinery" = {
      expr =
        builtins.deepSeq
          (krisis.effects.resultOf (
            primitive "tool" {
              kind = "command";
              declaration = literal;
            }
          )).value
          true;
      expected = true;
    };
    "test command context applies once" = {
      expr =
        let
          c = manifest (one {
            command = [ "true" ];
            cwd = "nested";
            env.VALUE = "x";
            timeout = 5;
          });
        in
        c.cwd == "nested"
        && (builtins.head c.steps).cwd == null
        && (builtins.head c.steps).env == { }
        && (builtins.head c.steps).timeout == null;
      expected = true;
    };
    "test explicit record parity" = {
      expr = manifest (one literal);
      expected = manifest (one {
        command = literal;
      });
    };
    "test shell is explicit" = {
      expr = builtins.elem "praxis/command-shape" (codes "echo implicit");
      expected = true;
    };
    "test shell is not rewritten" = {
      expr =
        (builtins.head
          (manifest (one {
            shell = "printf";
          })).steps
        ).run;
      expected = "printf";
    };
    "test old steps are not public" = {
      expr = builtins.elem "praxis/command-field" (codes {
        steps = [ "true" ];
      });
      expected = true;
    };
    "test empty argv rejected" = {
      expr = builtins.elem "praxis/exec-shape" (codes [ ]);
      expected = true;
    };
    "test contradictory forms stay lazy" = {
      expr = builtins.elem "praxis/execution-form" (codes {
        shell = poison;
        script = poison;
      });
      expected = true;
    };
    "test unknown field stays lazy" = {
      expr = builtins.elem "praxis/command-field" (codes {
        command = poison;
        typo = poison;
      });
      expected = true;
    };
    "test script path" = {
      expr =
        (builtins.head
          (manifest (compile {
            root = ./fixtures;
            commands.tool = ./fixtures/ci/fail.sh;
          })).steps
        ).script;
      expected = "ci/fail.sh";
    };
    "test script needs root" = {
      expr = builtins.elem "praxis/script-root" (codes ./fixtures/ci/fail.sh);
      expected = true;
    };
    "test script outside root" = {
      expr = builtins.elem "praxis/script-path" (
        map (d: d.code)
          (compile {
            root = ./fixtures;
            commands.tool = ../../flake.nix;
          }).diagnostics.tool
      );
      expected = true;
    };
    "test local targets" = {
      expr =
        (builtins.head
          (manifest (one {
            command = [
              "nix"
              "build"
            ];
            localFlake = true;
            args = [
              "hello"
              "two words"
            ];
          })).steps
        ).args;
      expected = [
        ".#hello"
        ".#two words"
      ];
    };
    "test no target guessing" = {
      expr =
        (builtins.head
          (manifest (one {
            command = [
              "nix"
              "build"
              "hello"
            ];
          })).steps
        ).exec;
      expected = [
        "nix"
        "build"
        "hello"
      ];
    };
    "test target context rejected" = {
      expr = builtins.elem "praxis/local-flake" (codes {
        shell = "true";
        localFlake = true;
      });
      expected = true;
    };
    "test ambiguous target rejected" = {
      expr = builtins.elem "praxis/local-flake" (codes {
        command = [ "nix" ];
        localFlake = true;
        args = [ "--help" ];
      });
      expected = true;
    };
    "test task kind" = {
      expr =
        (compile {
          commands.tool = literal;
          tasks.once = [ "tool" ];
        }).manifest.commands.once.kind;
      expected = "task";
    };
    "test task reference" = {
      expr =
        (builtins.head
          (compile {
            commands.tool = literal;
            tasks.once = [ "tool" ];
          }).manifest.commands.once.steps
        ).command;
      expected = "tool";
    };
    "test task order" = {
      expr =
        map (s: s.command)
          (compile {
            commands.tool = literal;
            tasks.once = [
              "tool"
              "tool"
            ];
          }).manifest.commands.once.steps;
      expected = [
        "tool"
        "tool"
      ];
    };
    "test task no broadcast" = {
      expr =
        builtins.all (s: !s.forwardArgs)
          (compile {
            commands.tool = literal;
            tasks.once = [
              "tool"
              "tool"
            ];
          }).manifest.commands.once.steps;
      expected = true;
    };
    "test task confirm once" = {
      expr =
        map (s: s.kind)
          (compile {
            tasks.once = {
              confirm = true;
              steps = [
                [ "true" ]
                [ "true" ]
              ];
            };
          }).manifest.commands.once.steps;
      expected = [
        "prompt"
        "exec"
        "exec"
      ];
    };
    "test task raw shell rejected" = {
      expr = rejected (compile { tasks.once = [ "echo not-a-reference" ]; }).manifest;
      expected = true;
    };
    "test duplicate command task" = {
      expr =
        rejected
          (compile {
            commands.same = poison;
            tasks.same = poison;
          }).availability.names;
      expected = true;
    };
    "test dispatcher name reserved" = {
      expr = rejected (compile { commands.praxis = literal; }).availability.names;
      expected = true;
    };
    "test custom dispatcher" = {
      expr =
        (compile {
          name = "work";
          commands.praxis = literal;
        }).manifest.name;
      expected = "work";
    };
    "test dispatcher alias reserved" = {
      expr = builtins.elem "praxis/aliases" (codes {
        command = literal;
        aliases = [ "praxis" ];
      });
      expected = true;
    };
    "test minimal output" = {
      expr = builtins.attrNames (one literal).packages;
      expected = [ "praxis" ];
    };
    "test minimal app" = {
      expr = builtins.attrNames (one literal).apps;
      expected = [ "praxis" ];
    };
    "test wrappers opt in" = {
      expr = (one literal).package.outPath;
      expected = (one literal).cli.outPath;
    };
    "test per command opt in" = {
      expr =
        builtins.attrNames
          (compile {
            commands.tool = literal;
            perCommand = true;
          }).packages;
      expected = [
        "praxis"
        "tool"
      ];
    };
    "test direct flake" = {
      expr = (one literal).flake.packages.x86_64-linux.praxis.outPath;
      expected = (one literal).package.outPath;
    };
    "test shell opt in" = {
      expr =
        (compile {
          commands.tool = literal;
          devShell = true;
        }).flake.devShells.x86_64-linux.default.packages != [ ];
      expected = true;
    };
    "test default check" = {
      expr = (compile { check = true; }).manifest.commands.check.steps != [ ];
      expected = true;
    };
    "test check conflict" = {
      expr =
        rejected
          (compile {
            check = true;
            commands.check = literal;
          }).manifest;
      expected = true;
    };
    "test check generation" = {
      expr = (guarded [ "true" ]).checks.tool.type;
      expected = "derivation";
    };
    "test check prompts rejected" = {
      expr =
        rejected
          (guarded {
            shell = "true";
            confirm = true;
          }).checks.tool;
      expected = true;
    };
    "test check interactive rejected" = {
      expr =
        rejected
          (guarded {
            shell = "true";
            interactive = true;
          }).checks.tool;
      expected = true;
    };
    "test check required parameter rejected" = {
      expr =
        rejected
          (guarded {
            command = [ "true" ];
            parameters = {
              value = {
                required = true;
              };
            };
          }).checks.tool;
      expected = true;
    };
    "test check fixed directory rejected" = {
      expr =
        rejected
          (guarded {
            shell = "true";
            cwd = "/repo";
          }).checks.tool;
      expected = true;
    };
    "test ownership optional" = {
      expr = (one literal).availability.trace == null && (one literal).availability.matrix == null;
      expected = true;
    };
    "test host selection" = {
      expr = (selected "x86_64-linux/desk").availability.names;
      expected = [
        "desk"
        "excluded"
        "global"
        "once"
        "predicate"
      ];
    };
    "test other host" = {
      expr = (selected "aarch64-linux/away").availability.names;
      expected = [
        "away"
        "global"
      ];
    };
    "test ownership inactive payload" = {
      expr =
        (compile {
          ownership = ownership "x86_64-linux/desk";
          commands.tool = literal;
          commands.unavailable = {
            hosts = [ "away" ];
            command = poison;
            packages = poison;
            ui = poison;
          };
          tasks.unavailable = {
            hosts = [ "away" ];
            steps = poison;
          };
        }).manifest.commands.tool.kind;
      expected = "command";
    };
    "test inactive path" = {
      expr =
        (compile {
          ownership = ownership "x86_64-linux/desk";
          commands.tool = literal;
          commands.missing = {
            hosts = [ "away" ];
            script = poison;
          };
        }).availability.names;
      expected = [ "tool" ];
    };
    "test unknown context" = {
      expr =
        rejected
          (compile {
            ownership = ownership "ghost";
            commands.tool = literal;
          }).availability.names;
      expected = true;
    };
    "test system rejects user claims" = {
      expr =
        rejected
          (compile {
            ownership = ownership "x86_64-linux/desk";
            commands.tool = {
              hosts = [ "away" ];
              users = [ "alex" ];
              command = poison;
            };
          }).availability.names;
      expected = true;
    };
    "test user context" = {
      expr =
        (compile {
          ownership = (ownership "x86_64-linux/desk") // {
            scope = "user";
            context = {
              host.id = "x86_64-linux/desk";
              user.name = "alex";
            };
          };
          units = [
            {
              hosts = [ "desk" ];
              children = [
                {
                  users = [ "alex" ];
                  commands.tool = literal;
                }
              ];
            }
          ];
        }).availability.names;
      expected = [ "tool" ];
    };
    "test user membership" = {
      expr =
        rejected
          (compile {
            ownership = (ownership "x86_64-linux/desk") // {
              scope = "user";
              context = {
                host.id = "x86_64-linux/desk";
                user.name = "sam";
              };
            };
            commands.tool = literal;
          }).availability.names;
      expected = true;
    };
    "test availability report" = {
      expr =
        builtins.stringLength (builtins.toJSON (selected "x86_64-linux/desk").availability.matrix) > 0;
      expected = true;
    };
    "test availability trace" = {
      expr = (selected "x86_64-linux/desk").availability.trace != null;
      expected = true;
    };
    "test large parameter declaration normalizes" = {
      expr =
        let
          names = builtins.genList (index: "arg${toString index}") 256;
          large = compile {
            commands.large = {
              positional = names;
              parameters = lib.genAttrs names (_: { });
              command = [ "true" ] ++ map (param: { inherit param; }) names;
            };
          };
        in
        large.diagnostics.large == [ ];
      expected = true;
    };
    "test selected command laziness" = {
      expr =
        (compile {
          commands.tool = literal;
          tasks.unused = poison;
        }).manifests.tool.commands.tool.kind;
      expected = "command";
    };
  };
in
{
  inherit tests;
}
