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
    literal-argv = (builtins.head (manifest (one literal)).steps).exec == literal;
    typo-help-without-payload-evaluation = lib.hasInfix "use 'command'" (
      builtins.toJSON (one { commnad = poison; }).diagnostics.tool
    );
    manifest-order-is-deterministic =
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
        }).manifest == builtins.toJSON
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
    availability-matrix-does-not-normalize-bodies =
      let
        text = builtins.toJSON availabilityProbe.matrix;
      in
      lib.hasInfix "commands.tool" text
      && lib.hasInfix "commands.unavailable" text
      && lib.hasInfix "x86_64-linux/desk" text
      && lib.hasInfix "aarch64-linux/away" text;
    availability-trace-keeps-bodies-lazy =
      map (entry: entry.name) availabilityProbe.trace.value.entries == [ "tool" ];
    inline-and-imported-declarations-match =
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
      }).manifest == (compile (import ./fixtures/public-surface.nix { inherit pkgs; })).manifest;
    default-forwarding = (builtins.head (manifest (one literal)).steps).forwardArgs;
    optional-metadata = (manifest (one literal)).description == "";
    primitive-never-forces-optional-machinery =
      builtins.deepSeq
        (primitive "tool" {
          kind = "command";
          declaration = literal;
        }).value
        true;
    command-context-applies-once =
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
    explicit-record-parity =
      manifest (one literal) == manifest (one {
        command = literal;
      });
    shell-is-explicit = builtins.elem "praxis/command-shape" (codes "echo implicit");
    shell-is-not-rewritten =
      (builtins.head
        (manifest (one {
          shell = "printf";
        })).steps
      ).run == "printf";
    old-steps-are-not-public = builtins.elem "praxis/command-field" (codes {
      steps = [ "true" ];
    });
    empty-argv-rejected = builtins.elem "praxis/exec-shape" (codes [ ]);
    contradictory-forms-stay-lazy = builtins.elem "praxis/execution-form" (codes {
      shell = poison;
      script = poison;
    });
    unknown-field-stays-lazy = builtins.elem "praxis/command-field" (codes {
      command = poison;
      typo = poison;
    });
    script-path =
      (builtins.head
        (manifest (compile {
          root = ./fixtures;
          commands.tool = ./fixtures/ci/fail.sh;
        })).steps
      ).script == "ci/fail.sh";
    script-needs-root = builtins.elem "praxis/script-root" (codes ./fixtures/ci/fail.sh);
    script-outside-root = builtins.elem "praxis/script-path" (
      map (d: d.code)
        (compile {
          root = ./fixtures;
          commands.tool = ../../flake.nix;
        }).diagnostics.tool
    );
    local-targets =
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
      ).args == [
        ".#hello"
        ".#two words"
      ];
    no-target-guessing =
      (builtins.head
        (manifest (one {
          command = [
            "nix"
            "build"
            "hello"
          ];
        })).steps
      ).exec == [
        "nix"
        "build"
        "hello"
      ];
    target-context-rejected = builtins.elem "praxis/local-flake" (codes {
      shell = "true";
      localFlake = true;
    });
    ambiguous-target-rejected = builtins.elem "praxis/local-flake" (codes {
      command = [ "nix" ];
      localFlake = true;
      args = [ "--help" ];
    });
    task-kind =
      (compile {
        commands.tool = literal;
        tasks.once = [ "tool" ];
      }).manifest.commands.once.kind == "task";
    task-reference =
      (builtins.head
        (compile {
          commands.tool = literal;
          tasks.once = [ "tool" ];
        }).manifest.commands.once.steps
      ).command == "tool";
    task-order =
      map (s: s.command)
        (compile {
          commands.tool = literal;
          tasks.once = [
            "tool"
            "tool"
          ];
        }).manifest.commands.once.steps == [
        "tool"
        "tool"
      ];
    task-no-broadcast =
      builtins.all (s: !s.forwardArgs)
        (compile {
          commands.tool = literal;
          tasks.once = [
            "tool"
            "tool"
          ];
        }).manifest.commands.once.steps;
    task-confirm-once =
      map (s: s.kind)
        (compile {
          tasks.once = {
            confirm = true;
            steps = [
              [ "true" ]
              [ "true" ]
            ];
          };
        }).manifest.commands.once.steps == [
        "prompt"
        "exec"
        "exec"
      ];
    task-raw-shell-rejected = rejected (compile { tasks.once = [ "echo not-a-reference" ]; }).manifest;
    duplicate-command-task =
      rejected
        (compile {
          commands.same = poison;
          tasks.same = poison;
        }).availability.names;
    dispatcher-name-reserved = rejected (compile { commands.praxis = literal; }).availability.names;
    custom-dispatcher =
      (compile {
        name = "work";
        commands.praxis = literal;
      }).manifest.name == "work";
    dispatcher-alias-reserved = builtins.elem "praxis/aliases" (codes {
      command = literal;
      aliases = [ "praxis" ];
    });
    minimal-output = builtins.attrNames (one literal).packages == [ "praxis" ];
    minimal-app = builtins.attrNames (one literal).apps == [ "praxis" ];
    wrappers-opt-in = (one literal).package.outPath == (one literal).cli.outPath;
    per-command-opt-in =
      builtins.attrNames
        (compile {
          commands.tool = literal;
          perCommand = true;
        }).packages == [
        "praxis"
        "tool"
      ];
    direct-flake =
      (one literal).flake.packages.x86_64-linux.praxis.outPath == (one literal).package.outPath;
    shell-opt-in =
      (compile {
        commands.tool = literal;
        devShell = true;
      }).flake.devShells.x86_64-linux.default.packages != [ ];
    default-check = (compile { check = true; }).manifest.commands.check.steps != [ ];
    check-conflict =
      rejected
        (compile {
          check = true;
          commands.check = literal;
        }).manifest;
    check-generation = (guarded [ "true" ]).checks.tool.type == "derivation";
    check-prompts-rejected =
      rejected
        (guarded {
          shell = "true";
          confirm = true;
        }).checks.tool;
    check-interactive-rejected =
      rejected
        (guarded {
          shell = "true";
          interactive = true;
        }).checks.tool;
    check-required-parameter-rejected =
      rejected
        (guarded {
          command = [ "true" ];
          parameters = [
            {
              name = "value";
              required = true;
            }
          ];
        }).checks.tool;
    check-fixed-directory-rejected =
      rejected
        (guarded {
          shell = "true";
          cwd = "/repo";
        }).checks.tool;
    ownership-optional =
      (one literal).availability.trace == null && (one literal).availability.matrix == null;
    host-selection =
      (selected "x86_64-linux/desk").availability.names == [
        "desk"
        "excluded"
        "global"
        "once"
        "predicate"
      ];
    other-host =
      (selected "aarch64-linux/away").availability.names == [
        "away"
        "global"
      ];
    ownership-inactive-payload =
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
      }).manifest.commands.tool.kind == "command";
    inactive-path =
      (compile {
        ownership = ownership "x86_64-linux/desk";
        commands.tool = literal;
        commands.missing = {
          hosts = [ "away" ];
          script = poison;
        };
      }).availability.names == [ "tool" ];
    unknown-context =
      rejected
        (compile {
          ownership = ownership "ghost";
          commands.tool = literal;
        }).availability.names;
    system-rejects-user-claims =
      rejected
        (compile {
          ownership = ownership "x86_64-linux/desk";
          commands.tool = {
            hosts = [ "away" ];
            users = [ "alex" ];
            command = poison;
          };
        }).availability.names;
    user-context =
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
      }).availability.names == [ "tool" ];
    user-membership =
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
    availability-report =
      builtins.stringLength (builtins.toJSON (selected "x86_64-linux/desk").availability.matrix) > 0;
    availability-trace = (selected "x86_64-linux/desk").availability.trace != null;
    large-parameter-declaration-normalizes =
      let
        names = builtins.genList (index: "arg${toString index}") 256;
        large = compile {
          commands.large = {
            parameters = map (name: {
              inherit name;
              positional = true;
              required = true;
            }) names;
            command = [ "true" ] ++ map (param: { inherit param; }) names;
          };
        };
      in
      large.diagnostics.large == [ ];
    selected-command-laziness =
      (compile {
        commands.tool = literal;
        tasks.unused = poison;
      }).manifests.tool.commands.tool.kind == "command";
  };
  failing = builtins.attrNames (lib.filterAttrs (_: pass: !pass) tests);
in
{
  inherit tests;
  ok =
    if failing == [ ] then
      true
    else
      throw "praxis public surface failed ${lib.concatStringsSep ", " failing}";
}
