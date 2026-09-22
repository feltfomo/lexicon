# the view answers off the same registries a run reads
{ lib, lexicon }:
let
  inherit (lexicon) kata;

  view =
    contributions: root:
    let
      door = lexicon.configure { inherit root contributions; };
    in
    lexicon.introspect {
      walked = door.value;
      prepared = (door.prepare door.value).value;
    };

  # one field no kind in this tree declares, the same contribution
  # tests/kata.nix hands its own door
  badge = instance: {
    fields.host = [
      {
        name = "badge";
        type = instance.t.String;
        default = "none";
      }
    ];
  };

  cross = view [ ] ./fixtures/cross;
  narrow = view [ ] ./fixtures/narrow;
  nested = view [ badge ] ./fixtures/nested;

  # fixtures/widened writes the contributed field, fixtures/nested leaves it
  # to its default
  widened = view [ badge ] ./fixtures/widened;

  # a walked set the tree would never ship, carrying a block name beside a
  # registered one
  strayWalked = {
    stray = kata.entry {
      nixos = { };
      nixso = { };
    };
  };

  strayLoaded = kata.load strayWalked;

  strayed = lexicon.introspect {
    walked = strayWalked;
    prepared = strayLoaded.value;
  };

  hostIn =
    answer: name: lib.findFirst (held: held.kind == "host" && held.name == name) null answer.fleet;

  originIn =
    answer: kind: name: field:
    (lib.findFirst (
      held: held.kind == kind && held.name == name && held.field == field
    ) null answer.origins).provenance;

  # names the arm a provenance landed in and carries its payload out
  answered = lexicon.introspection.types.Provenance.case {
    written = found: { written = found.sourcePath; };
    filled = field: { filled = field; };
  };
in
{
  testTheKindsViewAnswersOffTheKindRegistry = {
    expr = cross.kinds;
    expected = [
      {
        name = "entry";
        collection = "entries";
        declare = false;
        within = null;
        blocks = [
          "nixos"
          "homeManager"
          "furnish"
          "theme"
        ];
      }
      {
        name = "home";
        collection = "homes";
        declare = false;
        within = null;
        blocks = [
          "homeManager"
          "furnish"
          "theme"
        ];
      }
      {
        name = "user";
        collection = "users";
        declare = true;
        within = "host";
        blocks = [ ];
      }
      {
        name = "host";
        collection = "hosts";
        declare = true;
        within = null;
        blocks = [ ];
      }
    ];
  };

  # the order is the one the block registry resolved, and a route count is
  # what claimable means
  testTheBlocksViewAnswersOffTheBlockRegistry = {
    expr = cross.blocks;
    expected = [
      {
        name = "nixos";
        kinds = [ "entry" ];
        before = [ ];
        claimable = false;
        routes = [ ];
      }
      {
        name = "homeManager";
        kinds = [
          "entry"
          "home"
        ];
        before = [ ];
        claimable = false;
        routes = [ ];
      }
      {
        name = "theme";
        kinds = [
          "entry"
          "home"
        ];
        before = [ "furnish" ];
        claimable = false;
        routes = [ ];
      }
      {
        name = "furnish";
        kinds = [
          "entry"
          "home"
        ];
        before = [ ];
        claimable = true;
        routes = [
          [ ]
          [ "files" ]
          [ "directories" ]
          [
            "directories"
            "files"
          ]
        ];
      }
    ];
  };

  # fixtures/cross is a diamond, so the includes a file carries stop at the
  # ones the walk tied for it
  testEveryDeclarationCarriesItsOriginAndWhatItIncludes = {
    expr = cross.files;
    expected = [
      {
        name = "base";
        kind = "entry";
        origin = "modules/base.nix";
        blocks = [ "nixos" ];
        unregistered = [ ];
        includes = [
          "modules/tools/editor.nix"
          "modules/desktop.nix"
        ];
      }
      {
        name = "desktop";
        kind = "entry";
        origin = "modules/desktop.nix";
        blocks = [ "nixos" ];
        unregistered = [ ];
        includes = [ "modules/tools/editor.nix" ];
      }
      {
        name = "editor";
        kind = "entry";
        origin = "modules/tools/editor.nix";
        blocks = [ "nixos" ];
        unregistered = [ ];
        includes = [ ];
      }
    ];
  };

  testABlockNameTheRegistryNeverHeldIsKeptOutOfTheOnesItHolds = {
    expr = {
      reported = map (given: given.code) strayLoaded.diagnostics;
      inherit (strayed) files;
    };
    expected = {
      reported = [ "kata/unknown-block" ];
      files = [
        {
          name = "stray";
          kind = "entry";
          origin = null;
          blocks = [ "nixos" ];
          unregistered = [ "nixso" ];
          includes = [ ];
        }
      ];
    };
  };

  # the descent is the kind registry's, so the user lands inside each host
  # that included the file and once more as the host's child
  testANestedEntityStandsUnderItsParentInTheFleet = {
    expr = {
      held = map (one: "${one.kind} ${one.name}") nested.fleet;
      inherit ((hostIn nested "workstation")) children;
    };
    expected = {
      held = [
        "host laptop"
        "user ada"
        "host workstation"
        "user ada"
      ];
      children = {
        users = [ "ada" ];
      };
    };
  };

  testAWrittenFieldAnswersWithThePlaceItWasWrittenAt = {
    expr = {
      held = answered (originIn nested "host" "workstation" "system");
      contributed = answered (originIn widened "host" "workstation" "badge");
    };
    expected = {
      held = {
        written = [
          "hosts"
          "workstation"
          "system"
        ];
      };
      contributed = {
        written = [
          "hosts"
          "workstation"
          "badge"
        ];
      };
    };
  };

  testAFilledFieldAnswersWithTheFieldNameAndNothingElse = {
    expr = {
      held = answered (originIn nested "host" "workstation" "class");
      contributed = answered (originIn nested "host" "workstation" "badge");
    };
    expected = {
      held = {
        filled = "class";
      };
      contributed = {
        filled = "badge";
      };
    };
  };

  # fixtures/narrow claims one host by name, and the view is where a reader
  # sees which facets reached which machine
  testTheFacetsReachingAHostAreTheOnesItsClaimsAdmit = {
    expr = {
      workstation = (hostIn narrow "workstation").claimed.entries;
      laptop = (hostIn narrow "laptop").claimed.entries;
    };
    expected = {
      workstation = {
        desktop = [ "furnish" ];
      };
      laptop = { };
    };
  };

  # the renderer reads the answer beside it, so the counts in the print are
  # the origins counted once
  testTheRendererReadsTheAnswerItPrints = {
    expr = {
      header = builtins.head nested.lines;
      counted = lib.sublist (builtins.length nested.lines - 2) 2 nested.lines;
      wellTyped = lexicon.introspection.types.Introspection.check nested;
    };
    expected = {
      header = "lexicon 0.0.0, 4 kinds, 4 blocks, 3 declarations";
      counted = [
        "fields written by hand 6"
        "fields filled by lexicon 12"
      ];
      wellTyped = true;
    };
  };
}
