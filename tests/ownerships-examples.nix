{ lexicon, nixpkgs }:
let
  inherit (nixpkgs) lib;
  ownerships = lexicon.lib.ownerships { };
  examples = import ../examples/ownerships-suite.nix { inherit lexicon nixpkgs; };
  throws = value: !(builtins.tryEval (builtins.deepSeq value value)).success;
  roster = examples.claims.roster;
  context = examples.claims.context "workstation" "alice";
  units = examples.claims.units;
  expected = {
    tools = [
      "git"
      "helix"
    ];
  };
  resolvers = ownerships.mkResolvers roster;
  systemUnits = [
    {
      hosts = [ "workstation" ];
      answer = 42;
    }
  ];
  systemContext = {
    host.name = "workstation";
  };
  changed =
    (import (
      builtins.toFile "ownerships-minimal-changed.nix" (
        builtins.replaceStrings [ "editor = \"helix\";" ] [ "editor = \"vim\";" ] (
          builtins.readFile ../examples/ownerships-minimal/flake.nix
        )
      )
    )).outputs
      { inherit lexicon; };
  knownEmpty = ownerships.toRoster [
    (ownerships.define.host "laptop")
    (ownerships.define.user "alice" { hosts = [ ]; })
  ];
  unknown = ownerships.toRoster [
    (ownerships.define.host "laptop")
    (ownerships.define.user "alice" { })
  ];
  laptop = {
    host.name = "laptop";
    user.name = "alice";
  };
  preference = [ { editor = "helix"; } ];
  samples = {
    "minimal.result" = examples.minimal.result;
    "minimal.changed" = changed.lib.result;
    "preferences.alice" = examples.preferences.alice;
    "preferences.sam" = examples.preferences.sam;
    "preferences.laptop" = examples.preferences.laptop;
    "preferences.inspection" = examples.preferences.inspection;
    "preferences.matrix.coverage.preMerge.paths" = examples.preferences.matrix.coverage.preMerge.paths;
    "claims.alice" = examples.claims.alice;
    "claims.sam" = examples.claims.sam;
    "claims.laptop" = examples.claims.laptop;
    "merge.combined" = examples.merge.combined;
    "merge.replaced" = examples.merge.replaced;
    "merge.wholeEditor" = examples.merge.wholeEditor;
    "merge.deduplicated" = examples.merge.deduplicated;
    "files.home" = examples.files.home;
    "files.system" = examples.files.system;
    "files.moduleEditor" = examples.files.moduleEditor;
    "team.alice" = examples.team.alice;
    "team.sam" = examples.team.sam;
    "team.laptop" = examples.team.laptop;
    "team.robin" = examples.team.robin;
    "team.matrix.coverage.preMerge.paths.review" = examples.team.matrix.coverage.preMerge.paths.review;
  };
  tests = {
    "test first change" = {
      expr = changed.lib.result;
      expected = {
        editor = "vim";
      };
    };
    "test claims user miss" = {
      expr = examples.claims.sam;
      expected = {
        tools = [
          "git"
          "vim"
        ];
      };
    };
    "test user resolver parity" = {
      expr = lib.all (resolve: resolve units context == expected) [
        (ownerships.mkResolve roster)
        (ownerships.mkResolvePrepared roster)
        (ownerships.mkResolveStrict roster)
        (ownerships.mkResolveProfiled { } roster)
        resolvers.resolve
        resolvers.prepared
        resolvers.strict
        (resolvers.profiled { })
        (ownerships.resolverFor {
          inherit roster;
          projection = "prepared";
          strict = true;
        })
        (resolvers.resolverFor { projection = "value"; })
      ];
      expected = true;
    };
    "test system resolver parity" = {
      expr = lib.all (resolve: resolve systemUnits systemContext == { answer = 42; }) [
        (ownerships.mkResolveSystem roster)
        (ownerships.mkResolveSystemPrepared roster)
        (ownerships.mkResolveSystemStrict roster)
        (ownerships.mkResolveSystemProfiled { } roster)
        resolvers.resolveSystem
        resolvers.systemPrepared
        resolvers.systemStrict
        (resolvers.systemProfiled { })
      ];
      expected = true;
    };
    "test trace parity" = {
      expr =
        (ownerships.mkResolveTrace roster units context).value == expected
        && (ownerships.mkResolveSystemTrace roster systemUnits systemContext).value == { answer = 42; };
      expected = true;
    };
    "test matrix parity" = {
      expr =
        ownerships.mkResolveMatrix examples.preferences.roster {
          units = examples.preferences.units;
        } == examples.preferences.matrix
        &&
          ownerships.mkResolveSystemMatrix roster { units = systemUnits; }
          == resolvers.systemMatrix { units = systemUnits; };
      expected = true;
    };
    "test nested and predicate" = {
      expr = examples.claims.laptop;
      expected = {
        tools = [
          "git"
          "helix"
        ];
        editor.wrap = true;
        lowPower = true;
      };
    };
    "test disjoint nesting" = {
      expr = ownerships.mkResolve roster [
        {
          hosts = [ "workstation" ];
          children = [
            {
              hosts = [ "laptop" ];
              answer = 42;
            }
          ];
        }
      ] context;
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unlabeled unit \\{ answer \\}: axis 'host' claim can never be satisfied \\(disjoint nest or unknown name\\) \\(axis 'h";
    };
    "test mixed alias nesting" = {
      expr = ownerships.mkResolve roster [
        {
          hosts = [ "standalone/laptop" ];
          children = [
            {
              hosts = [ "laptop" ];
              answer = 42;
            }
          ];
        }
      ] laptop;
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unlabeled unit \\{ answer \\}: axis 'host' claim can never be satisfied \\(disjoint nest or unknown name\\) \\(axis 'h";
    };
    "test partial unknown claim" = {
      expr = ownerships.mkResolve roster [
        {
          hosts = [
            "missing"
            "workstation"
          ];
          answer = 42;
        }
      ] context;
      expected = {
        answer = 42;
      };
    };
    "test polarity" = {
      expr = ownerships.mkResolve roster [
        {
          hosts = [ "workstation" ];
          exceptHosts = [ "laptop" ];
          answer = 42;
        }
      ] context;
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/claim-polarity\\] a unit cannot set both 'hosts' and 'exceptHosts' -- pick the set or its complement";
    };
    "test system scope" = {
      expr = ownerships.mkResolveSystem roster [
        {
          children = [
            {
              users = [ "alice" ];
              answer = 42;
            }
          ];
        }
      ] systemContext;
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: a system-scope \\(host-only\\) unit sets 'users' = \\[\"alice\"\\] -- a host-only slice binds no user, so it";
    };
    "test metadata only" = {
      expr = ownerships.translate { label = "empty"; };
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/unit-metadata-only\\] unit 'empty' has ownership metadata but no config or children";
    };
    "test strict resolve accepts a user with unknown host membership" = {
      expr = ownerships.mkResolveStrict unknown preference laptop;
      expected = {
        editor = "helix";
      };
    };
    "test strict resolve rejects a user known to live on no host" = {
      expr = ownerships.mkResolveStrict knownEmpty preference laptop;
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unit 'standalone ctx host 'laptop', user 'alice'': no user in \\{ alice \\} lives on any host in \\{ standalone/la";
    };
    "test plain resolve applies global units on an unknown host" = {
      expr = ownerships.mkResolve roster preference { host.name = "missing"; };
      expected = {
        editor = "helix";
      };
    };
    "test strict resolve rejects an unknown host" = {
      expr = ownerships.mkResolveStrict roster preference { host.name = "missing"; };
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unit 'standalone ctx host 'missing'': axis 'host' claim can never be satisfied \\(disjoint nest or unknown nam";
    };
    "test empty axis" = {
      expr =
        ownerships.mkResolveSystem (ownerships.toRoster [ (ownerships.define.host "laptop") ]) preference
          {
            host.name = "laptop";
          };
      expectedError.type = "ThrownError";
      expectedError.msg = "ownerships: 1 ownership error\\(s\\):\n\\s*- unlabeled unit \\{ editor \\}: axis 'user' claim can never be satisfied \\(disjoint nest or unknown name\\) \\(axis 'u";
    };
    "test projected claims" = {
      expr = ownerships.projectClaims "system" {
        hosts = [ "laptop" ];
        users = [ "alice" ];
        marker = true;
      };
      expected = {
        hosts = [ "laptop" ];
        marker = true;
      };
    };
    "test scalar conflict" = {
      expr = examples.merge.conflict;
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/merge/conflict\\] conflict at editor\\.command: co-owners \"unit 'shared editor'\", \"unit 'chosen editor";
    };
    "test subtree replacement" = {
      expr =
        examples.merge.wholeEditor == {
          editor.command = "vim";
        }
        &&
          examples.merge.replaced == {
            editor = {
              command = "vim";
              wrap = true;
            };
          };
      expected = true;
    };
    "test list policy" = {
      expr =
        examples.merge.combined.tools == [
          "git"
          "git"
          "ripgrep"
        ]
        &&
          examples.merge.deduplicated.tools == [
            "git"
            "ripgrep"
          ];
      expected = true;
    };
    "test module priority resolves the files example editor" = {
      expr = examples.files.moduleEditor;
      expected = "helix";
    };
    "test unprioritized scalar co-owners conflict" = {
      expr = ownerships.mkResolve roster [
        { editor = "vim"; }
        { editor = "helix"; }
      ] context;
      expectedError.type = "ThrownError";
      expectedError.msg = "\\[ownerships/merge/conflict\\] conflict at editor: co-owners \"unlabeled unit \\{ editor \\}\" set differing values";
    };
    "test team membership" = {
      expr =
        examples.team.robin == examples.team.laptop
        && !(examples.team.sam ? review)
        && !(examples.team.alice.editor ? autosaveSeconds);
      expected = true;
    };
    "test prepared team" = {
      expr = ownerships.mkResolve examples.team.roster examples.team.units (
        examples.team.context "laptop" "robin"
      );
      expected = examples.team.robin;
    };
  };
in
{
  inherit samples tests;
  exports = builtins.attrNames ownerships;
  expectedFailures = [ "merge.conflict" ];
}
