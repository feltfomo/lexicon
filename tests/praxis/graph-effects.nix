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
    selected-namespace-leaf-keeps-siblings-lazy =
      builtins.attrNames project.manifests.once.commands == [
        "once"
        "tools.good"
      ];
    namespace-poison-control = !(builtins.tryEval project.manifests.tools.commands).success;
    malformed-parent-suppresses-child-lookup =
      projection malformed.diagnostics.once == [
        {
          code = "praxis/command-name";
          message = "subcommand names must be command-style names";
          label = "commands.tools.bad name";
        }
      ];
    reached-errors-keep-depth-first-order =
      projection failures.diagnostics.gate == [
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
    alias-errors-precede-sensitive-source-errors =
      projection collisions.diagnostics.gate == [
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
    failed-graph-summary-needs-no-builder =
      failures.diagnosticSummaries.gate == {
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
    successful-summary-keeps-runtime-inputs-opaque = opaque.diagnosticSummaries.selected.total == 0;
  };
  failing = builtins.attrNames (lib.filterAttrs (_: pass: !pass) tests);
in
{
  inherit tests;
  ok =
    if failing == [ ] then
      true
    else
      throw "praxis graph effects failed ${lib.concatStringsSep ", " failing}";
}
