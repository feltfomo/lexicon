{ lib, lexicon }:
let
  inherit (lexicon) kata;

  walked = root: lexicon.configure { inherit root; };

  codes = outcome: lib.sort (a: b: a < b) (map (given: given.code) outcome.diagnostics);

  places = outcome: map (given: given.at) outcome.diagnostics;

  inherit (kata.internal) types;

  cross = walked ./fixtures/cross;
  excluded = walked ./fixtures/excluded;
  collide = walked ./fixtures/collide;
  cyclic = walked ./fixtures/cyclic;
  strays = walked ./fixtures/strays;
  rotten = walked ./fixtures/badblock;
  miswritten = walked ./fixtures/miswritten;
  derived = walked ./fixtures/derived;
  nested = walked ./fixtures/nested;

  folded = outcome: kata.load outcome.value;
in
{
  testWalkReadsAConventionalTreeWhole = {
    expr = lib.sort (a: b: a < b) (builtins.attrNames cross.value);
    expected = [
      "base"
      "desktop"
      "editor"
    ];
  };

  testWalkStampsEachFileWithItsOwnOrigin = {
    expr = lib.mapAttrs (_: value: value.__kata.origin) cross.value;
    expected = {
      base = "modules/base.nix";
      desktop = "modules/desktop.nix";
      editor = "modules/tools/editor.nix";
    };
  };

  testWalkOriginIsRelativeToTheConfigurationRoot = {
    expr = {
      relative = types.Relative.check cross.value.editor.__kata.origin;
      absolute = types.Relative.check "/nix/store/anything/modules/tools/editor.nix";
    };
    expected = {
      relative = true;
      absolute = false;
    };
  };

  # a file the tree offered carries no name, and a name is what surviving the
  # exclusion list earns it
  testAnUnscreenedFileCannotPassAsAScreenedOne = {
    expr =
      let
        found = {
          root = "modules";
          relative = "tools/editor.nix";
          origin = "modules/tools/editor.nix";
        };
      in
      {
        discovered = types.Discovered.check found;
        screened = types.Screened.check found;
        named = types.Screened.check (found // { name = "editor"; });
      };
    expected = {
      discovered = true;
      screened = false;
      named = true;
    };
  };

  testWalkTiesTheKnotSoFilesCrossReference = {
    expr = map (value: value.__kata.origin) cross.value.base.__kata.includes;
    expected = [
      "modules/tools/editor.nix"
      "modules/desktop.nix"
    ];
  };

  testWalkResolvesADiamondThroughTheSameKnot = {
    expr = map (
      value: map (inner: inner.__kata.origin) value.__kata.includes
    ) cross.value.base.__kata.includes;
    expected = [
      [ ]
      [ "modules/tools/editor.nix" ]
    ];
  };

  testWalkOfASoundTreeReportsNothing = {
    expr = codes cross;
    expected = [ ];
  };

  # fixtures/derived computes its exclusions from the kind registry and from
  # the root it was handed. the five files under scratch are named after the
  # four kinds and the root, each carries a block that would fail the fold,
  # and only keep.nix is left if the settings file ran
  testASettingsFileComputesTheWalkFromTheLibraryHalf = {
    expr = {
      names = builtins.attrNames derived.value;
      reported = codes derived;
      folded = codes (folded derived);
    };
    expected = {
      names = [ "keep" ];
      reported = [ ];
      folded = [ ];
    };
  };

  testExclusionKeepsAFileOutOfTheWalk = {
    expr = {
      names = builtins.attrNames excluded.value;
      origin = excluded.value.dup.__kata.origin;
      reported = codes excluded;
    };
    expected = {
      names = [ "dup" ];
      origin = "modules/a/dup.nix";
      reported = [ ];
    };
  };

  testTwoFilesOnOneNameAreBothNamed = {
    expr = {
      reported = codes collide;
      inherit (collide) halted;
      notes = map (given: given.message) collide.diagnostics;
    };
    expected = {
      reported = [ "kata/entry-name-collision" ];
      halted = true;
      notes = [
        "\"dup\" is declared by more than one file, modules/a/dup.nix and modules/b/dup.nix"
      ];
    };
  };

  testACyclicTreeIsNamedRatherThanWalkedForever = {
    expr = codes (folded cyclic);
    expected = [ "kata/include-cycle" ];
  };

  testACyclicTreeNamesTheCycleItFound = {
    expr = map (given: given.message) (folded cyclic).diagnostics;
    expected = [
      "the includes run in a cycle, modules/a.nix -> modules/b.nix -> modules/a.nix"
    ];
  };

  testAMissingRootAnIdleExclusionAndAnUnknownKeyAreAllReported = {
    expr = codes strays;
    expected = [
      "kata/excluded-path-missing"
      "kata/unknown-walk-root"
      "settings/unknown-key"
    ];
  };

  testAnUnknownSettingsKeySuggestsTheOneItMeant = {
    expr = builtins.concatLists (map (given: given.notes) strays.diagnostics);
    expected = [ "did you mean 'roots'?" ];
  };

  # the declared keys are one record, so a value of the wrong shape is blamed
  # on the key that carries it
  testASettingsValueOfTheWrongShapeIsBlamedOnItsKey = {
    expr = {
      reported = codes miswritten;
      placed = places miswritten;
    };
    expected = {
      reported = [ "settings/malformed-value" ];
      placed = [ "$.\"kata.nix\".roots" ];
    };
  };

  testAnIdleExclusionIsPlacedOnTheKeyThatHoldsIt = {
    expr = builtins.elem "$.exclude.\"nowhere.nix\"" (places strays);
    expected = true;
  };

  testAWalkedFixtureCarryingABadBlockFailsTheBuild = {
    expr = {
      reported = codes (folded rotten);
      inherit ((folded rotten)) halted;
    };
    expected = {
      reported = [ "kata/nixos-interior" ];
      halted = true;
    };
  };

  testAnIncludeThatIsNotADeclarationIsReported = {
    expr = codes (kata.load { one = kata.entry { includes = [ 7 ]; }; });
    expected = [ "kata/foreign-include" ];
  };

  testAnIncludeFromNoFileCannotBePlaced = {
    expr = codes (kata.load { one = kata.entry { includes = [ (kata.entry { }) ]; }; });
    expected = [ "kata/unnameable-include" ];
  };

  # base pulls the editor directly and again through the desktop, and it
  # lands once
  testAnEntryPulledTwoWaysLandsOnce = {
    expr = builtins.attrNames (kata.check { } { base = cross.value.base; }).value.entries;
    expected = [
      "base"
      "desktop"
      "editor"
    ];
  };

  # a user in a file of its own reaches a host by being included, and the
  # second host that includes the same file gets the same user
  testAnIncludedUserLandsUnderEveryHostThatIncludesIt =
    let
      prepared = (folded nested).value;

      usersOf = name: prepared.registry.usersOf (prepared.registry.host name);
    in
    {
      expr = {
        reported = codes (folded nested);
        workstation = map (user: user.name) (usersOf "workstation");
        laptop = map (user: user.name) (usersOf "laptop");
        inherit ((builtins.head (usersOf "laptop"))) shell;
      };
      expected = {
        reported = [ ];
        workstation = [ "ada" ];
        laptop = [ "ada" ];
        shell = "/bin/fish";
      };
    };

  # the field landed where the layer below places a child, so it answers
  # through the one route to provenance
  testAnIncludedUserAnswersThroughOriginOf = {
    expr = (folded nested).value.registry.originOf {
      kind = "user";
      name = {
        host = "workstation";
        name = "ada";
      };
      field = "shell";
    };
    expected = {
      source = "declaration";
      sourcePath = [
        "hosts"
        "workstation"
        "users"
        "ada"
        "shell"
      ];
    };
  };
}
