# every case goes through a door. nothing here reaches into a phase
{
  lib,
  fx,
  lexicon,
  mkLexicon,
}:
let
  lex = lexicon;

  good = {
    hosts.igloo = {
      system = "x86_64-linux";
      users.tux = {
        shell = "/bin/fish";
      };
    };
  };

  broken = {
    hosts.igloo = {
      system = 1;
      shel = "/bin/fish";
      users.tux = {
        runtimeRoot = "relative/run";
      };
    };
    hosts.vm = {
      system = "x86_64-linux";
    };
    hsots = { };
  };

  brief =
    outcome:
    map (diagnostic: { inherit (diagnostic) code severity at; }) outcome.diagnostics
    |> lib.sort (a: b: a.code < b.code);

  found = code: outcome: builtins.filter (diagnostic: diagnostic.code == code) outcome.diagnostics;

  only =
    code: outcome:
    found code outcome
    |> map (diagnostic: {
      inherit (diagnostic) code severity at;
    });

  # a den configuration as den evaluates one. the builder field and the
  # user's whole host are throws, so anything that reads them fails loudly
  denConfig = {
    hosts.x86_64-linux.igloo = {
      hostName = "igloo";
      system = "x86_64-linux";
      class = "nixos";
      description = "nixos.igloo@x86_64-linux";
      tags = [ "lab" ];
      instantiate = throw "a builder field was read";
      users.tux = {
        userName = "tux";
        classes = [ "user" ];
        host = throw "a user's host was read";
      };
    };
  };

  # one den name under two systems, which our flat registry cannot keep apart
  denNarrowed = {
    hosts = {
      x86_64-linux.igloo = {
        system = "x86_64-linux";
        description = "nixos.igloo@x86_64-linux";
        users = { };
      };
      aarch64-linux.igloo = {
        system = "aarch64-linux";
        description = "nixos.igloo@aarch64-linux";
        users = { };
      };
    };
  };

  # a second den naming the same host under another system, with a user of
  # its own
  denOther = {
    hosts.aarch64-linux.igloo = {
      system = "aarch64-linux";
      description = "nixos.igloo@aarch64-linux";
      users.hopper = {
        userName = "hopper";
      };
    };
  };

  fromDen = config: declaration: declaration // { sources = [ (lex.source.den config { }) ]; };

  registry = (lex.load good).value;

  tux = registry.user {
    host = "igloo";
    name = "tux";
  };
in
{
  testFiveDistinctProblemsInOnePass = {
    expr = brief (lex.check broken);
    expected = [
      {
        code = "lexicon/invalid-value";
        severity = "error";
        at = "$.hosts.igloo.system";
      }
      {
        code = "lexicon/missing-field";
        severity = "error";
        at = "$.hosts.vm.users";
      }
      {
        code = "lexicon/requirement-failed";
        severity = "error";
        at = "$.hosts.igloo.users.tux.runtimeRoot";
      }
      {
        code = "lexicon/unknown-field";
        severity = "error";
        at = "$.hosts.igloo.shel";
      }
      {
        code = "lexicon/unknown-kind";
        severity = "error";
        at = "$.hsots";
      }
    ];
  };

  testEmptyUsersSucceeds = {
    expr =
      let
        outcome = lex.check {
          hosts.a = {
            system = "x86_64-linux";
            users = { };
          };
        };
      in
      {
        inherit (outcome) hasErrors total;
      };
    expected = {
      hasErrors = false;
      total = 0;
    };
  };

  testOmittedUsersIsMissingField = {
    expr = brief (lex.check { hosts.a.system = "x86_64-linux"; });
    expected = [
      {
        code = "lexicon/missing-field";
        severity = "error";
        at = "$.hosts.a.users";
      }
    ];
  };

  testUnknownFieldNamesTheKey = {
    expr =
      let
        diagnostic =
          builtins.head
            (lex.check {
              hosts.a = {
                system = "x86_64-linux";
                users.tux.shel = "/bin/fish";
              };
            }).diagnostics;
      in
      {
        inherit (diagnostic) code at notes;
        names = lib.hasInfix "shel" diagnostic.message;
      };
    expected = {
      code = "lexicon/unknown-field";
      at = "$.hosts.a.users.tux.shel";
      notes = [ "did you mean 'shell'?" ];
      names = true;
    };
  };

  testQueriesAnswer = {
    expr = {
      hosts = map (host: host.name) registry.hosts;
      inherit ((registry.host "igloo")) system;
      inherit ((registry.host "igloo")) class;
      users = map (user: user.name) (registry.usersOf (registry.host "igloo"));
      inherit (tux) shell;
      homeRoot = registry.homeRootOf tux;
      runtimeRoot = registry.runtimeRootOf tux;
      inherit (tux) extra;
      missing = registry.host "nope";
      diagnostics = registry.diagnosticsByPath;
    };
    expected = {
      hosts = [ "igloo" ];
      system = "x86_64-linux";
      class = "linux";
      users = [ "tux" ];
      shell = "/bin/fish";
      homeRoot = "/home/tux";
      runtimeRoot = null;
      extra = { };
      missing = null;
      diagnostics = { };
    };
  };

  testOriginOfIsTheOnlyRouteToProvenance = {
    expr = {
      declared = registry.originOf {
        kind = "host";
        name = "igloo";
        field = "system";
      };
      derived = registry.originOf {
        kind = "host";
        name = "igloo";
        field = "class";
      };
      child = registry.originOf {
        kind = "user";
        name = {
          host = "igloo";
          name = "tux";
        };
        field = "shell";
      };
      plain = builtins.attrNames (registry.host "igloo");
    };
    expected = {
      declared = {
        source = "declaration";
        sourcePath = [
          "hosts"
          "igloo"
          "system"
        ];
      };
      derived = null;
      child = {
        source = "declaration";
        sourcePath = [
          "hosts"
          "igloo"
          "users"
          "tux"
          "shell"
        ];
      };
      plain = [
        "class"
        "extra"
        "name"
        "system"
        "users"
      ];
    };
  };

  testFailedLoadHandsBackNoValue = {
    expr = (lex.load broken).value;
    expected = null;
  };

  testWrongTypedOptionalFieldIsInvalidValue = {
    expr = brief (
      lex.check {
        hosts.a = {
          system = "x86_64-linux";
          users.tux.shell = 42;
        };
      }
    );
    expected = [
      {
        code = "lexicon/invalid-value";
        severity = "error";
        at = "$.hosts.a.users.tux.shell";
      }
    ];
  };

  testRawRegistryIsUnreachable = {
    expr = builtins.filter (name: registry ? ${name}) [
      "entities"
      "registry"
      "provenance"
      "withDiagnostics"
    ];
    expected = [ ];
  };

  testRequireReportsThroughTheVocabulary = {
    expr =
      let
        outcome = lex.run { } good;
        found = krisisRun (outcome.value.require.host "igloo");
        absent = krisisRun (outcome.value.require.host "nope");
        krisisRun = lexicon.krisis.run { };
      in
      {
        found = found.value.name;
        inherit ((builtins.head absent.diagnostics)) code;
      };
    expected = {
      found = "igloo";
      code = "lexicon/unknown-host";
    };
  };

  testDerivedOverrideFiresAtInfo = {
    expr =
      let
        outcome = lex.load {
          hosts.a = {
            system = "x86_64-linux";
            class = "darwin";
            users = { };
          };
        };
      in
      {
        diagnostics = brief outcome;
        inherit (outcome) hasErrors;
        inherit ((outcome.value.host "a")) class;
      };
    expected = {
      diagnostics = [
        {
          code = "lexicon/derived-override";
          severity = "info";
          at = "$.hosts.a.class";
        }
      ];
      hasErrors = false;
      class = "darwin";
    };
  };

  testEmptySeamsAreSilent = {
    expr =
      let
        outcome = lex.run { contributions = [ ]; } (good // { sources = [ ]; });
      in
      {
        inherit (outcome) hasErrors total;
      };
    expected = {
      hasErrors = false;
      total = 0;
    };
  };

  testASourcesEntryThatIsNoSourceIsReported = {
    expr = brief (lex.check (good // { sources = [ "other" ]; }));
    expected = [
      {
        code = "lexicon/invalid-value";
        severity = "error";
        at = "$.sources[0]";
      }
    ];
  };

  testASourcesKeyThatIsNoListIsReported = {
    expr = brief (
      lex.check (
        good
        // {
          sources = {
            den = "other";
          };
        }
      )
    );
    expected = [
      {
        code = "lexicon/invalid-value";
        severity = "error";
        at = "$.sources";
      }
    ];
  };

  testForeignTypeFiresAcrossTwoInstances = {
    expr =
      let
        other = mkLexicon { inherit lib fx; };
      in
      only "lexicon/foreign-type" (
        lex.run {
          contributions = [
            (_: {
              fields.host = [
                {
                  name = "badge";
                  type = other.t.String;
                }
              ];
            })
          ];
        } good
      );
    expected = [
      {
        code = "lexicon/foreign-type";
        severity = "error";
        at = "$.host.badge";
      }
    ];
  };

  testOwnTypesAreNotForeign = {
    expr = only "lexicon/foreign-type" (
      lex.run {
        contributions = [
          (instance: {
            fields.host = [
              {
                name = "badge";
                type = instance.t.String;
                default = "none";
              }
            ];
          })
        ];
      } good
    );
    expected = [ ];
  };

  testDependencyOrderIsReported = {
    expr = only "lexicon/dependency-order" (
      lex.run {
        contributions = [
          (instance: {
            fields.host = [
              {
                name = "aaa";
                type = instance.t.String;
                default = "a";
                dependsOn = [ "zzz" ];
              }
              {
                name = "zzz";
                type = instance.t.String;
                default = "z";
              }
            ];
          })
        ];
      } good
    );
    expected = [
      {
        code = "lexicon/dependency-order";
        severity = "error";
        at = "$.host.aaa";
      }
    ];
  };

  testEmptyChecksSeamRuns = {
    expr = (lex.run { contributions = [ (_: { checks = [ ]; }) ]; } good).hasErrors;
    expected = false;
  };

  testExplainRendersAReport = {
    expr = lib.hasInfix "lexicon/unknown-kind" (lex.explain broken).report;
    expected = true;
  };

  testOrThrowThrowsOnlyOnErrors = {
    expr = {
      bad = (builtins.tryEval (lex.orThrow (lex.load broken))).success;
      ok = map (host: host.name) (lex.orThrow (lex.load good)).hosts;
    };
    expected = {
      bad = false;
      ok = [ "igloo" ];
    };
  };

  testAContributionAtTheDoorBuildsOnThisInstance = {
    expr =
      let
        outcome = lex.run {
          contributions = [
            (instance: {
              fields.host = [
                {
                  name = "badge";
                  type = instance.t.String;
                  default = "none";
                }
              ];
            })
          ];
        } good;
      in
      {
        foreign = only "lexicon/foreign-type" outcome;
        inherit (outcome) hasErrors;
        badge = outcome.value.badgeOf (outcome.value.host "igloo");
      };
    expected = {
      foreign = [ ];
      hasErrors = false;
      badge = "none";
    };
  };

  testAContributionFromAnotherInstanceIsStillForeign = {
    expr =
      let
        other = mkLexicon { inherit lib fx; };
      in
      only "lexicon/foreign-type" (
        lex.run {
          contributions = [
            (_: {
              fields.host = [
                {
                  name = "badge";
                  type = other.t.String;
                  default = "none";
                }
              ];
            })
          ];
        } good
      );
    expected = [
      {
        code = "lexicon/foreign-type";
        severity = "error";
        at = "$.host.badge";
      }
    ];
  };

  testTheDoorRejectsAnEntryThatIsNotAFunction = {
    expr = only "lexicon/invalid-value" (lex.run { contributions = [ "other" ]; } good);
    expected = [
      {
        code = "lexicon/invalid-value";
        severity = "error";
        at = "$.contributions[0]";
      }
    ];
  };

  testAContributionInsideAContributionIsUnimplemented = {
    expr = brief (
      lex.run {
        contributions = [
          (_: {
            contributions = [ ];
            nonsense = { };
          })
        ];
      } good
    );
    expected = [
      {
        code = "lexicon/unimplemented-key";
        severity = "error";
        at = "$.contributions[0]";
      }
      {
        code = "lexicon/unknown-field";
        severity = "error";
        at = "$.contributions[0].nonsense";
      }
    ];
  };

  testADeclarationWritingTheRetiredKeyIsToldWhereItWent =
    let
      diagnostic = builtins.head (found "lexicon/unknown-kind" (lex.check (good // { extend = [ ]; })));
    in
    {
      expr = {
        inherit (diagnostic) code severity at;
        told = builtins.any (note: lib.hasInfix "contributions" note) diagnostic.notes;
      };
      expected = {
        code = "lexicon/unknown-kind";
        severity = "error";
        at = "$.extend";
        told = true;
      };
    };

  testAContributionReturningTheRetiredKeyIsToldWhereItWent =
    let
      diagnostic = builtins.head (
        found "lexicon/unknown-field" (lex.run { contributions = [ (_: { extend = [ ]; }) ]; } good)
      );
    in
    {
      expr = {
        inherit (diagnostic) code severity at;
        told = builtins.any (note: lib.hasInfix "contributions" note) diagnostic.notes;
      };
      expected = {
        code = "lexicon/unknown-field";
        severity = "error";
        at = "$.contributions[0].extend";
        told = true;
      };
    };

  testContributedFieldsFollowListOrder =
    let
      alphaSpec = t: {
        name = "alpha";
        type = t.String;
        default = "a";
      };
      betaSpec = t: {
        name = "beta";
        type = t.String;
        default = "b";
        dependsOn = [ "alpha" ];
      };

      alpha = instance: { fields.host = [ (alphaSpec instance.t) ]; };
      beta = instance: { fields.host = [ (betaSpec instance.t) ]; };

      # beta may only depend on a field ordered before it, so whether the
      # dependency is reported is what says where the two contributions
      # landed relative to each other
      ordered = entries: only "lexicon/dependency-order" (lex.run { contributions = entries; } good);

      unordered = {
        code = "lexicon/dependency-order";
        severity = "error";
        at = "$.host.beta";
      };
    in
    {
      expr = {
        alphaFirst = ordered [
          alpha
          beta
        ];
        betaFirst = ordered [
          beta
          alpha
        ];
        oneEntryKeepsItsOwnFieldOrder = ordered [
          (instance: {
            fields.host = [
              (alphaSpec instance.t)
              (betaSpec instance.t)
            ];
          })
        ];
        oneEntryCannotReorderItsOwnFields = ordered [
          (instance: {
            fields.host = [
              (betaSpec instance.t)
              (alphaSpec instance.t)
            ];
          })
        ];
      };
      expected = {
        alphaFirst = [ ];
        betaFirst = [ unordered ];
        oneEntryKeepsItsOwnFieldOrder = [ ];
        oneEntryCannotReorderItsOwnFields = [ unordered ];
      };
    };

  testFieldAccessorsAreBuiltPerName = {
    expr = {
      host = registry.extraOf (registry.host "igloo");
      user = registry.extraOf tux;
    };
    expected = {
      host = { };
      user = { };
    };
  };

  testChildAccessorBeatsAFieldAccessorWhicheverResolvedFirst =
    let
      shapes = instance: {
        kinds = [
          {
            name = "gadget";
            collection = "gadgets";
            parent = "box";
            container = "gadgets";
            fields = [
              {
                name = "role";
                type = instance.t.nullOr instance.t.String;
                default = null;
              }
            ];
          }
          {
            name = "box";
            collection = "boxes";
            fields = [
              {
                name = "gadgets";
                type = instance.t.Attrs;
              }
            ];
          }
        ];
      };

      outcome = lex.run { contributions = [ shapes ]; } {
        hosts.igloo = {
          system = "x86_64-linux";
          users = { };
        };
        boxes.crate.gadgets.widget = { };
      };
    in
    {
      expr = {
        inherit (outcome) hasErrors;
        collisions = only "lexicon/accessor-collision" outcome;
        children = map (gadget: gadget.name) (outcome.value.gadgetsOf (outcome.value.box "crate"));
      };
      expected = {
        hasErrors = false;
        collisions = [ ];
        children = [ "widget" ];
      };
    };

  testAccessorCollisionsAreReported =
    let
      collisions =
        kinds:
        map (diagnostic: diagnostic.at) (
          only "lexicon/accessor-collision" (lex.run { contributions = [ (_: { inherit kinds; }) ]; } good)
        );
    in
    {
      expr = {
        sameCollection = collisions [
          {
            name = "box";
            collection = "hosts";
          }
        ];
        sameKindName = collisions [
          {
            name = "host";
            collection = "boxes";
          }
        ];
        nameOverAnotherCollection = collisions [
          {
            name = "hosts";
            collection = "boxes";
          }
        ];
        collectionEndingInOf = collisions [
          {
            name = "box";
            collection = "usersOf";
          }
        ];
      };
      expected = {
        sameCollection = [ "$.accessors.hosts" ];
        sameKindName = [ "$.accessors.host" ];
        nameOverAnotherCollection = [ "$.accessors.hosts" ];
        collectionEndingInOf = [
          "$.accessors.usersOf"
          "$.accessors.usersOf"
        ];
      };
    };

  testAccessorCollisionNamesBothRegistrants = {
    expr =
      let
        diagnostic = builtins.head (
          found "lexicon/accessor-collision" (
            lex.run {
              contributions = [
                (_: {
                  kinds = [
                    {
                      name = "box";
                      collection = "hosts";
                    }
                  ];
                })
              ];
            } good
          )
        );
      in
      {
        inherit (diagnostic) code severity at;
        names = lib.hasInfix "kind host" diagnostic.message && lib.hasInfix "kind box" diagnostic.message;
      };
    expected = {
      code = "lexicon/accessor-collision";
      severity = "error";
      at = "$.accessors.hosts";
      names = true;
    };
  };

  testMalformedChecksAreReported =
    let
      malformed =
        checks:
        only "lexicon/malformed-check" (lex.run { contributions = [ (_: { inherit checks; }) ]; } good);

      reported = position: {
        code = "lexicon/malformed-check";
        severity = "error";
        at = "$.checks[${toString position}]";
      };
    in
    {
      expr = {
        notAnAttrset = malformed [ "nope" ];
        withoutRun = malformed [ { name = "bare"; } ];
        withoutName = malformed [ { run = _: [ ]; } ];
        notAList = malformed [
          {
            name = "boolean";
            run = _: true;
          }
        ];
        threw = malformed [
          {
            name = "angry";
            run = _: throw "no";
          }
        ];
        duplicateName = malformed [
          {
            name = "twice";
            run = _: [ ];
          }
          {
            name = "twice";
            run = _: [ ];
          }
        ];
      };
      expected = {
        notAnAttrset = [ (reported 0) ];
        withoutRun = [ (reported 0) ];
        withoutName = [ (reported 0) ];
        notAList = [ (reported 0) ];
        threw = [ (reported 0) ];
        duplicateName = [ (reported 1) ];
      };
    };

  testOneBadCheckDoesNotStopTheRest =
    let
      outcome = lex.run {
        contributions = [
          (_: {
            checks = [
              {
                name = "angry";
                run = _: throw "no";
              }
              {
                name = "pair";
                run = _: [
                  {
                    detail = "first";
                    entities = [ "igloo" ];
                  }
                  {
                    detail = "second";
                    entities = [ "igloo" ];
                  }
                ];
              }
              {
                name = "last";
                run = _: [
                  {
                    detail = "third";
                    entities = [ "igloo" ];
                  }
                ];
              }
            ];
          })
        ];
      } good;
    in
    {
      expr = {
        malformed = map (diagnostic: diagnostic.at) (found "lexicon/malformed-check" outcome);
        details = map (diagnostic: diagnostic.message) (found "lexicon/check-failed" outcome);
      };
      expected = {
        malformed = [ "$.checks[0]" ];
        details = [
          "check \"pair\" failed on igloo, first"
          "check \"pair\" failed on igloo, second"
          "check \"last\" failed on igloo, third"
        ];
      };
    };

  testUniqueAcrossNamesBothEntities =
    let
      outcome =
        lex.run
          {
            contributions = [
              (instance: {
                checks = [
                  (instance.checks.uniqueAcross {
                    kind = "user";
                    field = "shell";
                  })
                ];
              })
            ];
          }
          {
            hosts.igloo = {
              system = "x86_64-linux";
              users.tux.shell = "/bin/fish";
            };
            hosts.vm = {
              system = "x86_64-linux";
              users.beastie.shell = "/bin/fish";
            };
          };

      diagnostic = builtins.head (found "lexicon/check-failed" outcome);
    in
    {
      expr = {
        inherit (diagnostic)
          code
          severity
          at
          notes
          message
          ;
      };
      expected = {
        code = "lexicon/check-failed";
        severity = "error";
        at = "$.hosts.igloo.users.tux.shell";
        notes = [ "$.hosts.vm.users.beastie.shell" ];
        message = "check \"unique-shell-across-user\" failed on igloo.tux, vm.beastie, more than one user declares the same shell";
      };
    };

  testReferenceExistsDoesNotBorrowAKindCode =
    let
      outcome =
        lex.run
          {
            contributions = [
              (instance: {
                fields.user = [
                  {
                    name = "buddy";
                    type = instance.t.nullOr instance.t.String;
                    default = null;
                  }
                ];
                checks = [
                  (instance.checks.referenceExists {
                    kind = "user";
                    field = "buddy";
                    target = "user";
                  })
                ];
              })
            ];
          }
          {
            hosts.igloo = {
              system = "x86_64-linux";
              users.tux.buddy = "igloo.nope";
            };
          };
    in
    {
      expr = {
        codes = map (diagnostic: diagnostic.code) outcome.diagnostics;
        at = map (diagnostic: diagnostic.at) (found "lexicon/check-failed" outcome);
        messages = map (diagnostic: diagnostic.message) (found "lexicon/check-failed" outcome);
      };
      expected = {
        codes = [ "lexicon/check-failed" ];
        at = [ "$.hosts.igloo.users.tux.buddy" ];
        messages = [
          "check \"buddy-of-user-names-a-user\" failed on igloo.tux, buddy names a user that was never declared"
        ];
      };
    };

  testExactlyOneReportsNoneAndSeveral =
    let
      primary = instance: {
        fields.host = [
          {
            name = "primary";
            type = instance.t.Bool;
            default = false;
          }
        ];
        checks = [
          (instance.checks.exactlyOne {
            kind = "host";
            field = "primary";
          })
        ];
      };

      failing =
        hosts: only "lexicon/check-failed" (lex.run { contributions = [ primary ]; } { inherit hosts; });

      plain = {
        system = "x86_64-linux";
        users = { };
      };
    in
    {
      expr = {
        none = failing { igloo = plain; };
        several = failing {
          igloo = plain // {
            primary = true;
          };
          vm = plain // {
            primary = true;
          };
        };
        one = failing {
          igloo = plain // {
            primary = true;
          };
        };
      };
      expected = {
        none = [
          {
            code = "lexicon/check-failed";
            severity = "error";
            at = null;
          }
        ];
        several = [
          {
            code = "lexicon/check-failed";
            severity = "error";
            at = "$.hosts.igloo.primary";
          }
        ];
        one = [ ];
      };
    };

  testAKindThatCollidesWithItselfIsReported =
    let
      outcome = lex.run {
        contributions = [
          (_: {
            kinds = [
              {
                name = "data";
                collection = "data";
              }
            ];
          })
        ];
      } good;

      diagnostic = builtins.head (found "lexicon/accessor-collision" outcome);
    in
    {
      expr = {
        collisions = only "lexicon/accessor-collision" outcome;
        names =
          lib.hasInfix "the collection of kind data" diagnostic.message
          && lib.hasInfix "the lookup for kind data" diagnostic.message;
      };
      expected = {
        collisions = [
          {
            code = "lexicon/accessor-collision";
            severity = "error";
            at = "$.accessors.data";
          }
        ];
        names = true;
      };
    };

  testContributionsMustBeAList = {
    expr = only "lexicon/invalid-value" (lex.run { contributions = _: { }; } good);
    expected = [
      {
        code = "lexicon/invalid-value";
        severity = "error";
        at = "$.contributions";
      }
    ];
  };

  testContributedFieldsForAKindMustBeAList = {
    expr = only "lexicon/invalid-value" (
      lex.run {
        contributions = [
          (instance: {
            fields.host = {
              name = "badge";
              type = instance.t.String;
              default = "none";
            };
          })
        ];
      } good
    );
    expected = [
      {
        code = "lexicon/invalid-value";
        severity = "error";
        at = "$.contributions[0].fields.host";
      }
    ];
  };

  testAFindingCannotRewriteItsOwnAttribution =
    let
      outcome = lex.run {
        contributions = [
          (_: {
            checks = [
              {
                name = "honest";
                run = _: [
                  {
                    detail = "the real detail";
                    entities = [ "igloo" ];
                    context = {
                      check = "someone else";
                      detail = "a different story";
                      entities = [ "nobody" ];
                      extra = "kept";
                    };
                  }
                ];
              }
            ];
          })
        ];
      } good;

      diagnostic = builtins.head (found "lexicon/check-failed" outcome);
    in
    {
      expr = {
        inherit (diagnostic.rendered)
          check
          detail
          entities
          extra
          ;
      };
      expected = {
        check = "\"honest\"";
        detail = "\"the real detail\"";
        entities = "\"igloo\"";
        extra = "\"kept\"";
      };
    };

  testAMalformedFindingIsReportedNotThrown =
    let
      outcome = lex.run {
        contributions = [
          (_: {
            checks = [
              {
                name = "shapes";
                run = _: [
                  {
                    detail = "entities as a bare string";
                    entities = "igloo";
                  }
                  {
                    detail = "first good";
                    entities = [ "igloo" ];
                  }
                  {
                    detail = "paths as a bare string";
                    entities = [ "igloo" ];
                    paths = "$.hosts.igloo";
                  }
                  {
                    detail = "second good";
                    entities = [ "igloo" ];
                  }
                  {
                    detail = "at as a bare string";
                    entities = [ "igloo" ];
                    at = "$.hosts.igloo";
                  }
                ];
              }
            ];
          })
        ];
      } good;
    in
    {
      expr = {
        malformed = map (diagnostic: diagnostic.at) (found "lexicon/malformed-check" outcome);
        reported = map (diagnostic: diagnostic.message) (found "lexicon/check-failed" outcome);
      };
      expected = {
        malformed = [
          "$.checks[0]"
          "$.checks[0]"
          "$.checks[0]"
        ];
        reported = [
          "check \"shapes\" failed on igloo, first good"
          "check \"shapes\" failed on igloo, second good"
        ];
      };
    };

  testContributedKindRecordKeysAreNotChecked =
    let
      outcome = lex.run {
        contributions = [
          (_: {
            kinds = [
              {
                name = "box";
                collection = "boxes";
                feilds = [ ];
              }
            ];
          })
        ];
      } good;
    in
    {
      expr = {
        inherit (outcome) hasErrors total;
        boxes = outcome.value.boxes;
      };
      expected = {
        hasErrors = false;
        total = 0;
        boxes = [ ];
      };
    };

  testADenConfigurationLandsInTheRegistry =
    let
      outcome = lex.load (fromDen denConfig { });
      found = outcome.value;
    in
    {
      expr = {
        inherit (outcome) hasErrors total;
        hosts = map (host: host.name) found.hosts;
        inherit ((found.host "igloo")) system class;
        users = map (user: user.name) (found.usersOf (found.host "igloo"));
        origin = found.originOf {
          kind = "host";
          name = "igloo";
          field = "system";
        };
        plain = builtins.attrNames (found.host "igloo");
      };
      expected = {
        hasErrors = false;
        total = 0;
        hosts = [ "igloo" ];
        system = "x86_64-linux";
        class = "linux";
        users = [ "tux" ];
        origin = {
          source = "den";
          sourcePath = [
            "sources"
            0
            "x86_64-linux"
            "igloo"
            "system"
          ];
        };
        plain = [
          "class"
          "extra"
          "name"
          "system"
          "users"
        ];
      };
    };

  testTwoSystemsNarrowingOntoOneNameAreOneDiagnostic =
    let
      outcome = lex.check (fromDen denNarrowed { });
      diagnostic = builtins.head (found "lexicon/narrowing-collision" outcome);
    in
    {
      expr = {
        collisions = only "lexicon/narrowing-collision" outcome;
        inherit (diagnostic) notes;
        systems =
          lib.hasInfix "x86_64-linux" diagnostic.message && lib.hasInfix "aarch64-linux" diagnostic.message;
        evidence = lib.hasInfix "nixos.igloo@aarch64-linux" diagnostic.message;
      };
      expected = {
        collisions = [
          {
            code = "lexicon/narrowing-collision";
            severity = "error";
            at = "$.sources[0].aarch64-linux.igloo";
          }
        ];
        notes = [ "$.sources[0].x86_64-linux.igloo" ];
        systems = true;
        evidence = true;
      };
    };

  testARenameNamingNoHostSuggests =
    let
      outcome = lex.check {
        sources = [
          (lex.source.den denConfig {
            renames = {
              "x86_64-linux/iglo" = "vm-amd";
            };
          })
        ];
      };
      diagnostic = builtins.head (found "lexicon/unknown-rename" outcome);
    in
    {
      expr = {
        reported = only "lexicon/unknown-rename" outcome;
        inherit (diagnostic) notes;
      };
      expected = {
        reported = [
          {
            code = "lexicon/unknown-rename";
            severity = "error";
            at = ''$.sources[0].renames."x86_64-linux/iglo"'';
          }
        ];
        notes = [ "did you mean 'x86_64-linux/igloo'?" ];
      };
    };

  testARenameTargetIsClaimedOnce =
    let
      reported =
        declaration:
        map (diagnostic: diagnostic.at) (found "lexicon/rename-collision" (lex.check declaration));
    in
    {
      expr = {
        twoRenames = reported {
          sources = [
            (lex.source.den denNarrowed {
              renames = {
                "aarch64-linux/igloo" = "one";
                "x86_64-linux/igloo" = "one";
              };
            })
          ];
        };
        ontoASourceHost = reported {
          sources = [
            (lex.source.den denNarrowed {
              renames = {
                "aarch64-linux/igloo" = "igloo";
              };
            })
          ];
        };
        ontoADeclaredHost = reported {
          hosts.box = {
            system = "x86_64-linux";
            users = { };
          };
          sources = [
            (lex.source.den denConfig {
              renames = {
                "x86_64-linux/igloo" = "box";
              };
            })
          ];
        };
      };
      expected = {
        twoRenames = [ ''$.sources[0].renames."x86_64-linux/igloo"'' ];
        ontoASourceHost = [ ''$.sources[0].renames."aarch64-linux/igloo"'' ];
        ontoADeclaredHost = [ ''$.sources[0].renames."x86_64-linux/igloo"'' ];
      };
    };

  testARenameThatChangesAPairingIsInfo = {
    expr = only "lexicon/rename-repairing" (
      lex.check {
        hosts.igloo = {
          system = "x86_64-linux";
          users = { };
        };
        sources = [
          (lex.source.den denConfig {
            renames = {
              "x86_64-linux/igloo" = "igloo-den";
            };
          })
        ];
      }
    );
    expected = [
      {
        code = "lexicon/rename-repairing";
        severity = "info";
        at = ''$.sources[0].renames."x86_64-linux/igloo"'';
      }
    ];
  };

  testTheAuthorWinsPerFieldAndTheLosingLineIsNamed =
    let
      outcome = lex.load (
        fromDen denConfig {
          hosts.igloo = {
            system = "aarch64-linux";
            users = { };
          };
        }
      );
    in
    {
      expr = {
        inherit (outcome) hasErrors;
        overrides = only "lexicon/source-override" outcome;
        names = map (diagnostic: lib.hasInfix "declaration" diagnostic.message) (
          found "lexicon/source-override" outcome
        );
        inherit ((outcome.value.host "igloo")) system;
        field = builtins.attrNames (outcome.value.host "igloo").users;
        entities = map (user: user.name) (outcome.value.usersOf (outcome.value.host "igloo"));
        origin = outcome.value.originOf {
          kind = "host";
          name = "igloo";
          field = "system";
        };
      };
      expected = {
        hasErrors = false;
        overrides = [
          {
            code = "lexicon/source-override";
            severity = "info";
            at = "$.sources[0].x86_64-linux.igloo.system";
          }
        ];
        names = [
          true
        ];
        system = "aarch64-linux";
        field = [ "tux" ];
        entities = [ "tux" ];
        origin = {
          source = "declaration";
          sourcePath = [
            "hosts"
            "igloo"
            "system"
          ];
          overridden = [
            {
              source = "den";
              sourcePath = [
                "sources"
                0
                "x86_64-linux"
                "igloo"
                "system"
              ];
            }
          ];
        };
      };
    };

  testAFlakeIsReportedWithTheOneLiner =
    let
      outcome = lex.check { sources = [ (lex.source.den { outputs = { }; } { }) ]; };
      diagnostic = builtins.head (found "lexicon/invalid-value" outcome);
    in
    {
      expr = {
        reported = only "lexicon/invalid-value" outcome;
        oneLiner = builtins.any (note: lib.hasInfix "flake.den = config.den" note) diagnostic.notes;
      };
      expected = {
        reported = [
          {
            code = "lexicon/invalid-value";
            severity = "error";
            at = "$.sources[0]";
          }
        ];
        oneLiner = true;
      };
    };

  testASourceNameCanBeWrittenDown =
    let
      outcome = lex.load {
        sources = [ (lex.source.den denConfig { name = "workstations"; }) ];
      };
    in
    {
      expr = {
        inherit (outcome) hasErrors;
        origin = outcome.value.originOf {
          kind = "host";
          name = "igloo";
          field = "system";
        };
      };
      expected = {
        hasErrors = false;
        origin = {
          source = "workstations";
          sourcePath = [
            "sources"
            0
            "x86_64-linux"
            "igloo"
            "system"
          ];
        };
      };
    };

  testTwoSourcesOfOneNameMergeRatherThanNarrow =
    let
      outcome = lex.load {
        sources = [
          (lex.source.den denConfig { name = "alpha"; })
          (lex.source.den denOther { name = "beta"; })
        ];
      };
      igloo = outcome.value.host "igloo";
    in
    {
      expr = {
        inherit (outcome) hasErrors;
        narrowing = only "lexicon/narrowing-collision" outcome;
        hosts = map (host: host.name) outcome.value.hosts;
        field = builtins.attrNames igloo.users;
        entities = lib.sort (left: right: left < right) (
          map (user: user.name) (outcome.value.usersOf igloo)
        );
        origin = outcome.value.originOf {
          kind = "host";
          name = "igloo";
          field = "system";
        };
      };
      expected = {
        hasErrors = false;
        narrowing = [ ];
        hosts = [ "igloo" ];
        field = [
          "hopper"
          "tux"
        ];
        entities = [
          "hopper"
          "tux"
        ];
        origin = {
          source = "beta";
          sourcePath = [
            "sources"
            1
            "aarch64-linux"
            "igloo"
            "system"
          ];
          overridden = [
            {
              source = "alpha";
              sourcePath = [
                "sources"
                0
                "x86_64-linux"
                "igloo"
                "system"
              ];
            }
          ];
        };
      };
    };

  testTwoSourcesSharingANameAreReported = {
    expr = only "lexicon/source-name-collision" (
      lex.check {
        sources = [
          (lex.source.den denConfig { })
          (lex.source.den denOther { })
        ];
      }
    );
    expected = [
      {
        code = "lexicon/source-name-collision";
        severity = "error";
        at = "$.sources[1]";
      }
    ];
  };

  # the second spec would take the first one's place in silence, so the
  # resolver names the field and both contributions that wrote it
  testTwoContributionsDeclaringOneFieldAreBothNamed =
    let
      badge = instance: {
        fields.host = [
          {
            name = "badge";
            type = instance.t.String;
            default = "none";
          }
        ];
      };

      outcome = lex.run {
        contributions = [
          badge
          badge
        ];
      } good;
    in
    {
      expr = {
        reported = only "lexicon/field-collision" outcome;
        messages = map (diagnostic: diagnostic.message) (found "lexicon/field-collision" outcome);
      };
      expected = {
        reported = [
          {
            code = "lexicon/field-collision";
            severity = "error";
            at = "$.host.badge";
          }
        ];
        messages = [
          "field \"badge\" is declared by both contributions[0] and contributions[1]"
        ];
      };
    };
}
