# the assembly, driven end to end. the blocks are exercised on their own
# elsewhere; what this watches is what happens between them, where a name is
# shared and the layer has to decide whether that is a clash or a coincidence
{
  krisis,
  telos,
}:
let
  # the package set is never read, because nothing here forces a derivation.
  # what is under test is which attributes exist and what was reported, and
  # both are answered before a builder would be
  assembled =
    declarations:
    krisis.run { policy = krisis.policy.collect; } (
      telos.assemble {
        inherit declarations;
        hosts = [
          {
            name = "tower";
            system = "x86_64-linux";
          }
        ];
        systems = [ "x86_64-linux" ];
        packageSets = {
          x86_64-linux = { };
        };
      }
    );

  sealed = {
    steps = [
      {
        name = "seal";
        run = "mkdir -p $out";
      }
    ];
  };

  # the fmt block's dependent half reads the package set, so a formatter test
  # hands one in with the name it declares
  assembledOver =
    packages: declarations:
    krisis.run { policy = krisis.policy.collect; } (
      telos.assemble {
        inherit declarations;
        hosts = [
          {
            name = "tower";
            system = "x86_64-linux";
          }
        ];
        systems = [ "x86_64-linux" ];
        packageSets = {
          x86_64-linux = packages;
        };
      }
    );

  # the table telos publishes is one table, and a reader who wants to know
  # what a table without a block does has to hand in that table
  assembledWith =
    table: declarations:
    krisis.run { policy = krisis.policy.collect; } (
      telos.internal.assembleWith table {
        inherit declarations;
        hosts = [
          {
            name = "tower";
            system = "x86_64-linux";
          }
        ];
        systems = [ "x86_64-linux" ];
        packageSets = {
          x86_64-linux = { };
        };
      }
    );

  # one name, one system, one block, written in two places
  collided = assembled {
    hosts.tower.checks.shared = sealed;
    fleet.checks.shared = sealed;
  };

  # the same bare name in two different blocks, which share nothing but the
  # word and land at two different attribute paths
  shared = assembled {
    hosts.tower.checks.greeting = sealed;
    fleet.packages.greeting = sealed;
  };

  reported = result: map (diagnostic: { inherit (diagnostic) code at message; }) result.diagnostics;
in
{
  # the sources are named as written and the value they were reduced from is
  # quoted, which is the difference between the two ways this vocabulary
  # reads an argument. nothing is projected, because the gate stops at the
  # first stage that reported and no later stage runs on a refused surface
  testTwoSourcesDeclaringOneOutputAreBothNamedAndNeitherSurvives = {
    expr = {
      diagnostics = reported collided;
      inherit (collided) halted;
      surface = collided.value;
    };
    expected = {
      diagnostics = [
        {
          code = "telos/output-name-collision";
          at = "$.checks.x86_64-linux.shared";
          message = ''"shared" is declared for "x86_64-linux" more than once, by fleet and tower'';
        }
      ];
      halted = true;
      surface = null;
    };
  };

  # a clash is decided by the attribute path an output lands at, so the same
  # word under two blocks is two outputs and neither is refused
  testOneNameUnderTwoBlocksIsNoClashAndBothSurvive = {
    expr = {
      diagnostics = reported shared;
      checks = builtins.attrNames shared.value.checks.x86_64-linux;
      packages = builtins.attrNames shared.value.packages.x86_64-linux;
    };
    expected = {
      diagnostics = [ ];
      checks = [ "greeting" ];
      packages = [ "greeting" ];
    };
  };

  # the attribute nix fmt reads holds one derivation and no names, so the one
  # formatter declared lands under the system itself
  testTheOneFormatterDeclaredLandsDirectlyUnderItsSystem = {
    expr =
      let
        result = assembledOver { nixfmt = "the program"; } {
          fleet.fmt = {
            tree = {
              program = "nixfmt";
            };
          };
        };
      in
      {
        diagnostics = reported result;
        formatter = result.value.formatter;
      };
    expected = {
      diagnostics = [ ];
      formatter = {
        x86_64-linux = "the program";
      };
    };
  };

  # two well formed formatters under different names clash nowhere a name is
  # compared, so the refusal is the placement's and it names both
  testTwoFormattersForOneSystemAreBothNamedAndNeitherLands = {
    expr =
      let
        result = assembledOver { nixfmt = "the program"; } {
          fleet.fmt = {
            tree = {
              program = "nixfmt";
            };
          };
          hosts.tower.fmt = {
            local = {
              program = "nixfmt";
            };
          };
        };
      in
      {
        diagnostics = reported result;
        surface = result.value;
      };
    expected = {
      diagnostics = [
        {
          code = "telos/contended-output-attribute";
          at = "$.fmt.x86_64-linux";
          message = ''"fmt" may declare one output for "x86_64-linux", and local and tree were declared by fleet and tower'';
        }
      ];
      surface = null;
    };
  };

  # leaving a block out of the table is how an output stays lexicon's own,
  # and the blocks still in the table are unaffected by the omission
  testABlockLeftOutOfTheTableReachesNoStandardAttribute = {
    expr =
      let
        result = assembledWith { checks = telos.placement.byName "checks"; } {
          fleet.checks.sealed = sealed;
          fleet.packages.greeting = sealed;
        };
      in
      {
        diagnostics = reported result;
        attributes = builtins.attrNames result.value;
        checks = builtins.attrNames result.value.checks.x86_64-linux;
      };
    expected = {
      diagnostics = [ ];
      attributes = [ "checks" ];
      checks = [ "sealed" ];
    };
  };

  # the declarations are an argument, so their own shape is the one thing no
  # block can be asked about
  testADeclarationsValueOfTheWrongShapeIsRefusedInTelosOwnWords = {
    expr = reported (assembled {
      fleet = "checks";
    });
    expected = [
      {
        code = "telos/malformed-declaration";
        at = "$.fleet";
        message = "the outputs declared by the fleet must be an attrset";
      }
    ];
  };
}
