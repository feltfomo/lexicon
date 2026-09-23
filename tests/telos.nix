# the outputs here are fake. what the suite watches is which direction of the
# ornament a payload survives, and whether a case analysis can be answered
# from the declared constructor set instead of from hope
{
  fx,
  krisis,
  telos,
}:
let
  H = fx.types.hoas;
  G = fx.types.generic;

  table = [
    {
      _con = "output";
      name = "tests";
      system = "x86_64-linux";
    }
    {
      _con = "output";
      name = "source-hygiene";
      system = "aarch64-linux";
    }
  ];

  drv = {
    type = "derivation";
    name = "tests";
    outPath = "/nix/store/00000000000000000000000000000000-tests";
  };

  entry = {
    _con = "output";
    name = "tests";
    system = "x86_64-linux";
    inherit drv;
  };

  declaredEntry = entry // {
    origin = "lexicon/tests";
  };

  thunkedEntry = entry // {
    drv = fx.state.mkThunk drv;
  };

  fails = value: !(builtins.tryEval (builtins.deepSeq value null)).success;

  Box = H.datatype "Box" [
    (H.con "box" [ (H.field "name" H.string) ])
  ];

  boxWithLaws = G.ornaments.functional {
    base = Box;
    spec = {
      name = "TaggedBox";
      constructors.box.fields = [
        { keep = "name"; }
        {
          insert = "tag";
          type = H.string;
        }
      ];
    };
    synth.constructors.box.fields.tag = ctx: ctx.baseRecord.name;
    laws.checks.always = _: true;
  };

  Placement = H.datatype "Placement" [
    (H.con "classed" [ (H.field "class" H.string) ])
    (H.con "carried" [ (H.field "carrier" H.string) ])
  ];

  classed = {
    _con = "classed";
    class = "packages";
  };

  arms = {
    classed = value: value.class;
    carried = value: value.carrier;
  };

  # a law that elaborates cleanly and simply disagrees, which is the failure a
  # real round trip mismatch takes rather than the one a refused record takes
  declaredWithFalseLaw = H.functionalOrnament {
    inherit (telos.declared)
      ornament
      chooseIndex
      section
      indexProof
      ;
    laws.checks.forget-section = _: false;
  };

  collect = comp: krisis.run { policy = krisis.policy.collect; } comp;

  codesOf = result: map (diagnostic: diagnostic.code) result.diagnostics;
in
{
  testDeclaredOutputForgetsToTheStandardOutput = {
    expr = map (record: telos.project telos.declared (telos.section telos.declared record)) table;
    expected = table;
  };

  testSectionTypeChecksTheRecordItIsGiven = {
    expr = fails (telos.section telos.declared (builtins.head table // { system = 0; }));
    expected = true;
  };

  testGenericSynthesisDropsTheLawBundle = {
    expr = boxWithLaws.laws;
    expected = { };
  };

  testRoundTripLawRunsThroughTheHoasOrnament = {
    expr = G.ornaments.validateFunctionalLaws (telos.withRoundTripLaw telos.declared table);
    expected = {
      ok = true;
      diagnostics = [ ];
    };
  };

  # a law slot that is never read would pass this too, so the same law is run
  # against a record the kernel refuses
  testRoundTripLawIsNotVacuous = {
    expr =
      map (diagnostic: diagnostic.code)
        (G.ornaments.validateFunctionalLaws (
          telos.withRoundTripLaw telos.declared [ (builtins.head table // { system = 0; }) ]
        )).diagnostics;
    expected = [ "functional.law-eval-failed" ];
  };

  # the throwing law only proves the slot is read. this is the mismatch the
  # round trip actually relies on being reported
  testALawThatDisagreesIsReportedAgainstItsPath = {
    expr = map (diagnostic: {
      inherit (diagnostic) code path;
    }) (G.ornaments.validateFunctionalLaws declaredWithFalseLaw).diagnostics;
    expected = [
      {
        code = "functional.law-failed";
        path = [
          "functionalOrnament"
          "laws"
          "forget-section"
        ];
      }
    ];
  };

  testDerivationCrossesForgetButNotSection = {
    expr = {
      forgotten = telos.projectRecord telos.declaredEntry declaredEntry;
      sectioned = fails (telos.section telos.declaredEntry entry);
    };
    expected = {
      forgotten = entry;
      sectioned = true;
    };
  };

  testThunkingTheDerivationDoesNotRescueSection = {
    expr = fails (telos.section telos.declaredThunkEntry thunkedEntry);
    expected = true;
  };

  testMissingBuilderIsReportedOnBothSides = {
    expr = {
      kernel = map (diagnostic: {
        inherit (diagnostic) code path;
      }) (telos.validateSpec { synth = { }; }).diagnostics;

      mapped = map (diagnostic: {
        inherit (diagnostic) code at;
      }) (collect (telos.reportSpec { synth = { }; })).diagnostics;
    };
    expected = {
      kernel = [
        {
          code = "functional.missing-builder";
          path = [
            "functional"
            "constructors"
            "output"
            "fields"
            "origin"
          ];
        }
      ];
      mapped = [
        {
          code = "telos/output-builder-missing";
          at = "$.functional.constructors.output.fields.origin";
        }
      ];
    };
  };

  testCaseAnalysisDispatchesWhenTheArmsMatch = {
    expr =
      let
        result = collect (
          telos.caseOf {
            datatype = Placement;
            inherit arms;
          } classed
        );
      in
      {
        inherit (result) value;
        codes = codesOf result;
      };
    expected = {
      value = "packages";
      codes = [ ];
    };
  };

  testMissingArmIsCaughtAgainstTheDeclaredSet = {
    expr =
      let
        result = collect (
          telos.caseOf {
            datatype = Placement;
            arms = {
              inherit (arms) classed;
            };
          } classed
        );
      in
      {
        inherit (result) halted;
        codes = codesOf result;
      };
    expected = {
      halted = true;
      codes = [ "telos/case-arm-missing" ];
    };
  };

  testUnknownArmIsCaughtAgainstTheDeclaredSet = {
    expr =
      let
        result = collect (
          telos.caseOf {
            datatype = Placement;
            arms = arms // {
              scattered = value: value.class;
            };
          } classed
        );
      in
      codesOf result;
    expected = [ "telos/case-arm-unknown" ];
  };
}
