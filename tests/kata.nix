# every case goes through a door. nothing here reaches into a phase
{ lib, lexicon }:
let
  inherit (lexicon) kata;

  walked = kata.from "/etc/x/editor.nix";

  brief =
    outcome:
    map (diagnostic: { inherit (diagnostic) code severity at; }) outcome.diagnostics
    |> lib.sort (a: b: a.code < b.code);

  notesOf = outcome: map (diagnostic: diagnostic.notes) outcome.diagnostics;

  # a sound registration, so a case that hands the registry a bad one says in
  # one place what it made wrong
  registered =
    name: extra:
    {
      inherit name;
      kinds = [ "entry" ];
      before = [ ];
      claimable = [ ];
      codes = { };
      validate = _: null;
      compile = {
        independent = _: null;
        dependent = _: _: null;
      };
    }
    // extra;

  workstation = kata.host {
    declare = {
      system = "x86_64-linux";
      users = { };
    };
  };

  # one field no kind in this tree declares, so a case can tell a widening
  # from a collision
  badge = instance: {
    fields.host = [
      {
        name = "badge";
        type = instance.t.String;
        default = "none";
      }
    ];
  };

  opened =
    contributions:
    lexicon.configure {
      root = ./fixtures/widened;
      inherit contributions;
    };
in
{
  testKataEntryConstructsInert = {
    expr = (kata.entry { nixos = { }; }).__kata;
    expected = {
      kind = "entry";
      origin = null;
      includes = [ ];
      declare = { };
      blocks = {
        nixos = { };
      };
      spec = {
        nixos = { };
      };
    };
  };

  testKataHomeConstructsInert = {
    expr = (kata.home { }).__kata;
    expected = {
      kind = "home";
      origin = null;
      includes = [ ];
      declare = { };
      blocks = { };
      spec = { };
    };
  };

  testKataUserConstructsInert = {
    expr =
      (kata.user {
        declare = {
          shell = "/bin/fish";
        };
      }).__kata;
    expected = {
      kind = "user";
      origin = null;
      includes = [ ];
      declare = {
        shell = "/bin/fish";
      };
      blocks = { };
      spec = {
        declare = {
          shell = "/bin/fish";
        };
      };
    };
  };

  testKataHostConstructsInert = {
    expr =
      (walked.host {
        declare = {
          system = "x86_64-linux";
        };
      }).__kata;
    expected = {
      kind = "host";
      origin = "/etc/x/editor.nix";
      includes = [ ];
      declare = {
        system = "x86_64-linux";
      };
      blocks = { };
      spec = {
        declare = {
          system = "x86_64-linux";
        };
      };
    };
  };

  # includes is carried and nothing more. it is not resolved, merged, or
  # checked against anything yet
  testKataIncludesAreCarriedInert = {
    expr =
      (kata.host {
        declare = { };
        includes = [ "ada" ];
      }).__kata.includes;
    expected = [ "ada" ];
  };

  testKataUnknownKindIsReportedAtItsOrigin = {
    expr = brief (kata.check { } { editor = walked.of "entyr" { }; });
    expected = [
      {
        code = "kata/unknown-kind";
        severity = "error";
        at = ''$."/etc/x/editor.nix"'';
      }
    ];
  };

  testKataUnknownKindSuggests = {
    expr = notesOf (kata.check { } { editor = walked.of "entyr" { }; });
    expected = [ [ "did you mean 'entry'?" ] ];
  };

  testKataDisallowedBlockIsReported = {
    expr = brief (kata.check { } { git = kata.home { nixos = { }; }; });
    expected = [
      {
        code = "kata/disallowed-block";
        severity = "error";
        at = "$.git.nixos";
      }
    ];
  };

  testKataAllowedBlockIsAccepted = {
    expr = brief (kata.check { } { editor = kata.entry { nixos = { }; }; });
    expected = [ ];
  };

  testKataUnbuiltValueIsReported = {
    expr = brief (
      kata.check { } {
        git = {
          homeManager = { };
        };
      }
    );
    expected = [
      {
        code = "kata/malformed-construction";
        severity = "error";
        at = "$.git";
      }
    ];
  };

  testKataMalformedPayloadBlamesTheField = {
    expr = brief (kata.check { } { workstation = kata.host { declare = "nope"; }; });
    expected = [
      {
        code = "kata/malformed-construction";
        severity = "error";
        at = "$.workstation.declare";
      }
    ];
  };

  # the seam. what reaches the layer below carries no tag, no origin and no
  # includes, and a declare has been unwrapped into the fields the entity
  # kind already holds
  testKataFoldsToAPlainDeclaration = {
    expr = kata.internal.declarationOf {
      inherit workstation;
      editor = walked.entry { nixos = { }; };
    };
    expected = {
      hosts.workstation = {
        system = "x86_64-linux";
        users = { };
      };
      entries.editor = {
        blocks = {
          nixos = { };
        };
      };
    };
  };

  # a host lands on the entity kind that already owns system and users
  testKataHostReachesTheEntityKind = {
    expr = (kata.load { inherit workstation; }).hasErrors;
    expected = false;
  };

  testKataEntryReachesTheContributedKind = {
    expr = (kata.load { editor = kata.entry { nixos = { }; }; }).hasErrors;
    expected = false;
  };

  testKataRegistersFourBlocks = {
    expr = lib.sort (a: b: a < b) kata.internal.blocks.names;
    expected = [
      "furnish"
      "homeManager"
      "nixos"
      "theme"
    ];
  };

  testKataRegistrationIsClean = {
    expr = kata.internal.blocks.problems;
    expected = [ ];
  };

  # the registry reads whatever entries it is handed, so a registration the
  # layer would never ship is still something a case can build
  testKataRegistrationReportsAnUnknownField = {
    expr = (kata.internal.blocks.of [ (registered "praxis" { kind = [ "entry" ]; }) ]).problems;
    expected = [
      {
        code = "malformed-registration";
        args = {
          at = [
            "praxis"
            "kind"
          ];
          context = {
            block = "praxis";
            field = "kind";
            expected = "a field this registry reads";
          };
          notes = [ "did you mean 'kinds'?" ];
        };
      }
    ];
  };

  testKataRegistrationReportsAnUnknownEdge = {
    expr =
      (kata.internal.blocks.of [
        (registered "praxis" { before = [ "furnisch" ]; })
        (registered "furnish" { })
      ]).problems;
    expected = [
      {
        code = "unknown-block-edge";
        args = {
          at = [
            "praxis"
            "before"
          ];
          context = {
            block = "praxis";
            edge = "furnisch";
          };
          notes = [ "did you mean 'furnish'?" ];
        };
      }
    ];
  };

  testKataRegistrationReportsACycle = {
    expr =
      (kata.internal.blocks.of [
        (registered "one" { before = [ "two" ]; })
        (registered "two" { before = [ "one" ]; })
      ]).problems;
    expected = [
      {
        code = "block-cycle";
        args = {
          at = [
            "one"
            "before"
          ];
          context = {
            cycle = [
              "one"
              "two"
            ];
          };
        };
      }
    ];
  };

  # the declared list puts furnish ahead of theme on purpose. drop theme's
  # edge, or turn it around, and this comes back the other way
  testKataThemeIsOrderedBeforeFurnish = {
    expr = builtins.filter (name: name == "theme" || name == "furnish") kata.internal.blocks.order;
    expected = [
      "theme"
      "furnish"
    ];
  };

  testKataOrderingIsNotTheDeclaredOrder = {
    expr = builtins.filter (name: name == "theme" || name == "furnish") kata.internal.blocks.names;
    expected = [
      "furnish"
      "theme"
    ];
  };

  testKataThemeIsLegalInAnEntry = {
    expr = brief (
      kata.check { } {
        ghostty = kata.entry {
          theme = {
            id = "ghostty";
            output = ".config/ghostty/themes/skadi.conf";
            reload = "pkill -USR2 ghostty";
            renderers.noctalia = {
              source = "/configs/ghostty/themes/skadi.conf";
              sharedWith = [ "dms" ];
            };
          };
        };
      }
    );
    expected = [ ];
  };

  testKataThemeTemplatesAreAccepted = {
    expr = brief (
      kata.check { } {
        qt = kata.entry {
          theme = {
            id = "qt";
            templates = [
              {
                subId = "qt5ct";
                output = ".config/qt5ct/colors/reactive.conf";
                placedAs = "qt5ct.conf";
                renderers.caelestia.source = "/configs/qt/caelestia.conf";
              }
            ];
          };
        };
      }
    );
    expected = [ ];
  };

  # the block's own validator reported this, and the entry it sat in is what
  # places it
  testKataBlockValidatorIsPlacedAtTheEntry = {
    expr = brief (
      kata.check { } {
        ghostty = walked.entry {
          theme = {
            id = "ghostty";
            renderers.noctalia = { };
          };
        };
      }
    );
    expected = [
      {
        code = "kata/theme-malformed-field";
        severity = "error";
        at = ''$."/etc/x/editor.nix".theme.renderers.noctalia.source'';
      }
    ];
  };

  testKataUnknownBlockFieldSuggests = {
    expr = notesOf (
      kata.check { } {
        ghostty = kata.entry {
          theme = {
            id = "ghostty";
            renderers.noctalia.sourse = "/configs/ghostty/themes/skadi.conf";
          };
        };
      }
    );
    expected = [
      [ "did you mean 'source'?" ]
      [ ]
    ];
  };

  # a block belonging to a subsystem that does not exist yet is carried until
  # the caller asks for strict
  testKataUnknownBlockIsAWarning = {
    expr = brief (kata.check { } { editor = kata.entry { praxis = { }; }; });
    expected = [
      {
        code = "kata/unknown-block";
        severity = "warning";
        at = "$.editor.praxis";
      }
    ];
  };

  testKataStrictMakesAnUnknownBlockAnError = {
    expr = brief (kata.check { strict = true; } { editor = kata.entry { praxis = { }; }; });
    expected = [
      {
        code = "kata/unknown-block";
        severity = "error";
        at = "$.editor.praxis";
      }
    ];
  };

  # a kind that takes its fields behind declare carries no blocks, so a block
  # written beside that key is a placement and nothing else at that position is
  testKataThemeIsIllegalOnAUser =
    let
      outcome = kata.check { } {
        ada = kata.user {
          declare = { };
          theme = { };
        };
      };
    in
    {
      expr = {
        reported = brief outcome;
        notes = notesOf outcome;
      };
      expected = {
        reported = [
          {
            code = "kata/disallowed-block";
            severity = "error";
            at = "$.ada.theme";
          }
          {
            code = "kata/unplaced-declaration";
            severity = "error";
            at = "$.ada";
          }
        ];
        notes = [
          [ ]
          [ ]
        ];
      };
    };

  testKataStrayKeyOnAUserIsMalformed = {
    expr = brief (
      kata.check { } {
        ada = kata.user {
          declare = { };
          shell = "/bin/fish";
        };
      }
    );
    expected = [
      {
        code = "kata/malformed-construction";
        severity = "error";
        at = "$.ada.shell";
      }
      {
        code = "kata/unplaced-declaration";
        severity = "error";
        at = "$.ada";
      }
    ];
  };

  # a claim three levels inside a declared route is recognised, and the same
  # shape at a route nobody declared is left alone
  testKataClaimIsReadAtADeclaredRoute = {
    expr = brief (
      kata.check { } {
        desktop = kata.entry {
          furnish.directories = [
            {
              src = "/configs/desktop";
              dest = ".config/desktop";
              files = [
                {
                  names = [ "monitors-workstation.conf" ];
                  hosts = "workstation";
                }
              ];
            }
          ];
        };
      }
    );
    expected = [
      {
        code = "kata/malformed-claim";
        severity = "error";
        at = "$.desktop.furnish.directories[0].files[0].hosts";
      }
    ];
  };

  testKataWellFormedClaimIsAccepted = {
    expr = brief (
      kata.check { } {
        desktop = kata.entry {
          furnish = {
            hosts = [
              "workstation"
              "laptop"
            ];
            directories = [
              {
                src = "/configs/desktop";
                dest = ".config/desktop";
                files = [
                  {
                    names = [ "monitors-laptop.conf" ];
                    hosts = [ "laptop" ];
                  }
                ];
              }
            ];
          };
        };
      }
    );
    expected = [ ];
  };

  # the same key inside a block that declared no route for it is data
  testKataClaimShapedValueOffRouteIsLeftAlone = {
    expr = brief (
      kata.check { } {
        steam = kata.entry {
          homeManager = {
            users = {
              ada = { };
            };
          };
        };
      }
    );
    expected = [ ];
  };

  # a declared route reaching a node that only exists once the module
  # arguments do is a defect in the route, reported once per route that
  # stopped there, and the block's own shape check names the same node
  testKataUnwalkableClaimRouteIsReported = {
    expr = brief (kata.check { } { desktop = kata.entry { furnish.directories = _: [ ]; }; });
    expected = [
      {
        code = "kata/furnish-malformed-field";
        severity = "error";
        at = "$.desktop.furnish.directories";
      }
      {
        code = "kata/unwalkable-claim-route";
        severity = "error";
        at = "$.desktop.furnish.directories";
      }
      {
        code = "kata/unwalkable-claim-route";
        severity = "error";
        at = "$.desktop.furnish.directories";
      }
    ];
  };

  testKataClaimKeysComeOffTheKindRegistry = {
    expr = lib.sort (a: b: a < b) kata.internal.claims.keys;
    expected = [
      "hosts"
      "users"
    ];
  };

  # a user is included by something that holds no users. the includer and the
  # kind the user belongs to are both named, and the user lands nowhere
  testKataAUserIncludedByAnEntryIsMisplaced =
    let
      elsewhere = kata.from "/etc/x/ada.nix";

      outcome = kata.check { } {
        editor = walked.entry { includes = [ (elsewhere.user { declare = { }; }) ]; };
      };
    in
    {
      expr = {
        reported = brief outcome;
        messages = map (diagnostic: diagnostic.message) outcome.diagnostics;
        holds = builtins.attrNames outcome.value;
      };
      expected = {
        reported = [
          {
            code = "kata/misplaced-include";
            severity = "error";
            at = "$.editor";
          }
        ];
        messages = [ "editor includes the user ada, which belongs to a host" ];
        holds = [ "entries" ];
      };
    };

  # a kind that lands in a parent reaches a declaration through the value
  # that includes it, and nothing included this one
  testKataAUserNothingIncludesIsUnplaced =
    let
      outcome = kata.check { } { ada = kata.user { declare = { }; }; };
    in
    {
      expr = {
        reported = brief outcome;
        messages = map (diagnostic: diagnostic.message) outcome.diagnostics;
        holds = builtins.attrNames outcome.value;
      };
      expected = {
        reported = [
          {
            code = "kata/unplaced-declaration";
            severity = "error";
            at = "$.ada";
          }
        ];
        messages = [ "nothing includes the user ada, so it reaches no host" ];
        holds = [ ];
      };
    };

  # a field no kind in this tree declares reaches the layer below because the
  # caller handed one down at the door
  testKataACallerContributionReachesTheLayerBelow =
    let
      door = opened [ badge ];

      outcome = door.prepare door.value;
    in
    {
      expr = {
        reported = brief outcome;
        badge = outcome.value.registry.badgeOf (outcome.value.registry.host "workstation");
      };
      expected = {
        reported = [ ];
        badge = "gold";
      };
    };

  testKataTheSameFieldWithoutTheContributionIsUnknown =
    let
      door = opened [ ];
    in
    {
      expr = brief (door.prepare door.value);
      expected = [
        {
          code = "lexicon/unknown-field";
          severity = "error";
          at = "$.hosts.workstation.badge";
        }
      ];
    };

  # the entry kind is one this tree contributes, so it is still registered
  # while the caller's own contribution is in the same stream
  testKataACallerContributionJoinsTheTreesOwn =
    let
      door = opened [ badge ];

      outcome = door.prepare door.value;
    in
    {
      expr = map (one: one.name) outcome.value.registry.entries;
      expected = [ "base" ];
    };

  # the tree already declares system, so a contribution declaring it again is
  # no widening, and the message names the caller's own list position
  testKataACollidingCallerContributionIsReported =
    let
      door = opened [
        badge
        (instance: {
          fields.host = [
            {
              name = "system";
              type = instance.t.String;
            }
          ];
        })
      ];

      outcome = door.prepare door.value;
    in
    {
      expr = {
        reported = brief outcome;
        messages = map (diagnostic: diagnostic.message) outcome.diagnostics;
      };
      expected = {
        reported = [
          {
            code = "lexicon/field-collision";
            severity = "error";
            at = "$.host.system";
          }
        ];
        messages = [ "field \"system\" is declared by both kind host and contributions[1]" ];
      };
    };
}
