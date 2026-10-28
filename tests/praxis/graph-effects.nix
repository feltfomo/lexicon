{
  lib,
  axiom,
  krisis,
}:
let
  poison = throw "praxis graph forced an unrelated payload";
  pkgs = {
    bash = "/bash";
    rustPlatform.buildRustPackage = _: poison;
    writeText = _: _: poison;
    writeShellApplication = _: poison;
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
  project = compile {
    commands = {
      tools.good = [ "true" ];
      tools.unused = poison;
      unrelated = poison;
    };
    tasks.once = [ "tools.good" ];
  };
  malformed = compile {
    pkgs = poison;
    commands.tools."bad name" = poison;
    tasks.once = [ "tools.good" ];
  };
  failures = compile {
    pkgs = poison;
    commands.unrelated = poison;
    tasks = {
      gate = [
        "cycle-a"
        "absent"
        "invalid"
        "cycle-a"
      ];
      cycle-a = [ "cycle-b" ];
      cycle-b = [ "cycle-a" ];
      invalid = [ ];
    };
  };
  collisions = compile {
    pkgs = poison;
    tasks.gate = {
      parameters.token = {
        sensitive = true;
        env = "DEPLOY_TOKEN";
      };
      steps = [
        "a"
        "b"
      ];
    };
    commands = {
      a = {
        aliases = [ "both" ];
        parameters.ordinary.env = "DEPLOY_TOKEN";
        command = [ "true" ];
      };
      b = {
        aliases = [ "both" ];
        command = [ "true" ];
      };
      unrelated = poison;
    };
  };
  opaque = compile {
    pkgs = poison;
    commands = {
      selected = {
        command = [ "true" ];
        packages = [
          {
            type = "derivation";
            outPath = poison;
            drvPath = poison;
          }
        ];
      };
      sibling = poison;
    };
  };
  projection =
    diagnostics:
    map (d: {
      inherit (d) code message;
      label = d.primary.label;
    }) diagnostics;
  tests = {
    "test selected namespace leaf keeps siblings lazy" = {
      expr = builtins.attrNames project.manifests.once.commands;
      expected = [
        "once"
        "tools.good"
      ];
    };
    "test namespace poison control" = {
      expr = !(builtins.tryEval project.manifests.tools.commands).success;
      expected = true;
    };
    "test malformed parent suppresses child lookup" = {
      expr = projection malformed.diagnostics.once;
      expected = [
        {
          code = "praxis/command-name";
          message = "subcommand names must be command-style names";
          label = "commands.tools.bad name";
        }
      ];
    };
    "test reached errors keep depth first order" = {
      expr = projection failures.diagnostics.gate;
      expected = [
        {
          code = "praxis/command-cycle";
          message = "command cycle gate -> cycle-a -> cycle-b -> cycle-a";
          label = "commands.cycle-a";
        }
        {
          code = "praxis/command-reference";
          message = "unknown command 'absent'";
          label = "commands.absent";
        }
        {
          code = "praxis/task-steps";
          message = "tasks need a non-empty steps list";
          label = "tasks.invalid";
        }
      ];
    };
    "test alias errors precede sensitive source errors" = {
      expr = projection collisions.diagnostics.gate;
      expected = [
        {
          code = "praxis/aliases";
          message = "alias 'both' belongs to multiple commands a, b";
          label = "commands";
        }
        {
          code = "praxis/parameter-sensitive";
          message = "sensitive environment names cannot feed ordinary defaults, overrides, conditions or prompt responses";
          label = "commands.a";
        }
      ];
    };
    "test failed graph summary needs no builder" = {
      expr = failures.diagnosticSummaries.gate;
      expected = {
        total = 3;
        hasErrors = true;
        bySeverity = {
          error = 3;
          warning = 0;
          info = 0;
        };
        byCode = {
          "praxis/command-cycle" = 1;
          "praxis/command-reference" = 1;
          "praxis/task-steps" = 1;
        };
      };
    };
    "test successful summary keeps runtime inputs opaque" = {
      expr = opaque.diagnosticSummaries.selected.total;
      expected = 0;
    };
  };
in
{
  inherit tests;
}
