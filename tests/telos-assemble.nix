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
