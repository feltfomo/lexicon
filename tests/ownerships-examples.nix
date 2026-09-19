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
  cases = {
    firstChange = changed.lib.result == { editor = "vim"; };
    claimsUserMiss =
      examples.claims.sam == {
        tools = [
          "git"
          "vim"
        ];
      };
    userResolverParity = lib.all (resolve: resolve units context == expected) [
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
    systemResolverParity = lib.all (resolve: resolve systemUnits systemContext == { answer = 42; }) [
      (ownerships.mkResolveSystem roster)
      (ownerships.mkResolveSystemPrepared roster)
      (ownerships.mkResolveSystemStrict roster)
      (ownerships.mkResolveSystemProfiled { } roster)
      resolvers.resolveSystem
      resolvers.systemPrepared
      resolvers.systemStrict
      (resolvers.systemProfiled { })
    ];
    traceParity =
      (ownerships.mkResolveTrace roster units context).value == expected
      && (ownerships.mkResolveSystemTrace roster systemUnits systemContext).value == { answer = 42; };
    matrixParity =
      ownerships.mkResolveMatrix examples.preferences.roster {
        units = examples.preferences.units;
      } == examples.preferences.matrix
      &&
        ownerships.mkResolveSystemMatrix roster { units = systemUnits; }
        == resolvers.systemMatrix { units = systemUnits; };
    nestedAndPredicate =
      examples.claims.laptop == {
        tools = [
          "git"
          "helix"
        ];
        editor.wrap = true;
        lowPower = true;
      };
    disjointNesting = throws (
      ownerships.mkResolve roster [
        {
          hosts = [ "workstation" ];
          children = [
            {
              hosts = [ "laptop" ];
              answer = 42;
            }
          ];
        }
      ] context
    );
    mixedAliasNesting = throws (
      ownerships.mkResolve roster [
        {
          hosts = [ "standalone/laptop" ];
          children = [
            {
              hosts = [ "laptop" ];
              answer = 42;
            }
          ];
        }
      ] laptop
    );
    partialUnknownClaim =
      ownerships.mkResolve roster [
        {
          hosts = [
            "missing"
            "workstation"
          ];
          answer = 42;
        }
      ] context == {
        answer = 42;
      };
    polarity = throws (
      ownerships.mkResolve roster [
        {
          hosts = [ "workstation" ];
          exceptHosts = [ "laptop" ];
          answer = 42;
        }
      ] context
    );
    systemScope = throws (
      ownerships.mkResolveSystem roster [
        {
          children = [
            {
              users = [ "alice" ];
              answer = 42;
            }
          ];
        }
      ] systemContext
    );
    metadataOnly = throws (ownerships.translate { label = "empty"; });
    unknownMembership =
      ownerships.mkResolveStrict unknown preference laptop == {
        editor = "helix";
      }
      && throws (ownerships.mkResolveStrict knownEmpty preference laptop);
    strictGlobal =
      ownerships.mkResolve roster preference { host.name = "missing"; } == {
        editor = "helix";
      }
      && throws (ownerships.mkResolveStrict roster preference { host.name = "missing"; });
    emptyAxis = throws (
      ownerships.mkResolveSystem (ownerships.toRoster [ (ownerships.define.host "laptop") ]) preference {
        host.name = "laptop";
      }
    );
    projectedClaims =
      ownerships.projectClaims "system" {
        hosts = [ "laptop" ];
        users = [ "alice" ];
        marker = true;
      } == {
        hosts = [ "laptop" ];
        marker = true;
      };
    scalarConflict = throws examples.merge.conflict;
    subtreeReplacement =
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
    listPolicy =
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
    modulePriority =
      examples.files.moduleEditor == "helix"
      && throws (
        ownerships.mkResolve roster [
          { editor = "vim"; }
          { editor = "helix"; }
        ] context
      );
    teamMembership =
      examples.team.robin == examples.team.laptop
      && !(examples.team.sam ? review)
      && !(examples.team.alice.editor ? autosaveSeconds);
    preparedTeam =
      ownerships.mkResolve examples.team.roster examples.team.units (
        examples.team.context "laptop" "robin"
      ) == examples.team.robin;
  };
  failing = builtins.filter (name: !cases.${name}) (builtins.attrNames cases);
in
{
  inherit samples cases;
  exports = builtins.attrNames ownerships;
  expectedFailures = [ "merge.conflict" ];
  ok =
    if failing == [ ] then
      true
    else
      throw "ownerships examples failed: ${lib.concatStringsSep ", " failing}";
}
