# every case goes through a door. the capability is built here because
# nothing under src may name the tree it comes out of
{ lib, lexicon }:
let
  inherit (lexicon) kata krisis emission;

  codes = outcome: lib.sort (a: b: a < b) (map (given: given.code) outcome.diagnostics);

  places = outcome: map (given: given.at) outcome.diagnostics;

  # the tree the suite's lib was imported from, recovered from where lib's
  # own attributes were written. the suite bakes that tree in as a store
  # path, so the capability closes over a store path
  tree = dirOf (dirOf (builtins.unsafeGetAttrPos "mkIf" lib).file);

  # the attribute that evaluates a system is published on the flake output
  # of that tree and is not on the lib imported out of it, which is why an
  # evaluator can only arrive as a capability. read 2026-09-21
  systemEvaluator = arguments: import (tree + "/nixos/lib/eval-config.nix") arguments;

  capabilities = {
    inherit systemEvaluator;
  };

  configured =
    root: given:
    lexicon.configure {
      inherit root;
      capabilities = given;
    };

  emitted =
    root: given:
    let
      door = configured root given;
    in
    door.emit (kata.load door.value).value;

  whole = (emitted ./fixtures/emission capabilities).value;

  narrowed = (emitted ./fixtures/narrow capabilities).value;

  twofold = (emitted ./fixtures/twofold capabilities).value;

  valued = (emitted ./fixtures/valued capabilities).value;

  claimed = kata.load (lexicon.configure { root = ./fixtures/claims; }).value;

  aspectOf = (emission.aspectFor emission.backends.byName.den).of;

  reported = value: krisis.run { } (aspectOf value);

  denAspect = lexicon.toDenAspect (kata.entry { nixos = { }; });

  # the wrapper is a functor carrying its advertised names, which is what
  # the module system and the aspect system both read
  argumentsOf = module: lib.sort (a: b: a < b) (builtins.attrNames (lib.functionArgs module));

  # a registration the tree would never ship, read by the same registry
  miswired = {
    name = "miswired";
    needs = [ ];
    supplies = [ "host" ];
    binds = [ ];
    context = [
      "pkgs"
      "hosty"
    ];
    classes = [ "nixos" ];
    emit =
      { host, ... }:
      {
        inherit host;
        modules = [ ];
        carried = { };
        built = null;
      };
  };

  # registered soundly and hollow, so the door reaches the point where a
  # backend hands something back
  hollow = {
    name = "hollow";
    needs = [ ];
    supplies = [ ];
    binds = [ ];
    context = [ "pkgs" ];
    classes = [ "nixos" ];
    emit = _: null;
  };
in
{
  testEmissionRunsEveryPlacementOverEveryHost = {
    expr = {
      placements = lib.sort (a: b: a < b) (builtins.attrNames whole);
      hosts = builtins.attrNames whole.native;
      reported = codes (emitted ./fixtures/emission capabilities);
    };
    expected = {
      placements = [
        "den"
        "native"
      ];
      hosts = [ "workstation" ];
      reported = [ ];
    };
  };

  # one compiler, one wrapper, two placements. the two agree on the
  # derivation or they do not agree at all
  testOneCompilerTwoPlacementsAgreeOnTheDerivation = {
    expr =
      whole.native.workstation.built.config.system.build.toplevel.drvPath
      == whole.den.workstation.built.config.system.build.toplevel.drvPath;
    expected = true;
  };

  # each placement carries one module per interior. den contributes the
  # binding as one more module for the whole host, and native binds through
  # the evaluator and contributes none
  testEachPlacementCarriesOneModulePerInteriorAndDenItsBinder = {
    expr = {
      native = builtins.length whole.native.workstation.modules;
      den = builtins.length whole.den.workstation.modules;
      nativeTwofold = builtins.length twofold.native.workstation.modules;
      denTwofold = builtins.length twofold.den.workstation.modules;
      entries = lib.sort (a: b: a < b) (builtins.attrNames twofold.native.workstation.carried);
      wellTyped = emission.types.Target.check whole.native.workstation;
    };
    expected = {
      native = 1;
      den = 2;
      nativeTwofold = 2;
      denTwofold = 3;
      entries = [
        "base"
        "extra"
      ];
      wellTyped = true;
    };
  };

  # two interiors on one host is the shape that named the binder defect. the
  # binding is defined once for the host, and both placements land on the
  # same derivation
  testTwoInteriorsOnOneHostAgreeOnTheDerivation = {
    expr = {
      reported = codes (emitted ./fixtures/twofold capabilities);
      agreed =
        twofold.native.workstation.built.config.system.build.toplevel.drvPath
        == twofold.den.workstation.built.config.system.build.toplevel.drvPath;
    };
    expected = {
      reported = [ ];
      agreed = true;
    };
  };

  # the entity is read where the module system reads a definition value, and
  # the two placements bind it by different routes. a value-position read is
  # the shape that lands on one derivation through both
  testAnInteriorReadingTheEntityAsAValueAgreesAcrossPlacements =
    let
      readBack = placement: {
        inherit (valued.${placement}.workstation.built.config.environment.variables)
          LEXICON_CLASS
          LEXICON_USERS
          ;
      };
    in
    {
      expr = {
        reported = codes (emitted ./fixtures/valued capabilities);
        agreed =
          valued.native.workstation.built.config.system.build.toplevel.drvPath
          == valued.den.workstation.built.config.system.build.toplevel.drvPath;
        native = readBack "native";
        den = readBack "den";
      };
      expected = {
        reported = [ ];
        agreed = true;
        native = {
          LEXICON_CLASS = "linux";
          LEXICON_USERS = "ada";
        };
        den = {
          LEXICON_CLASS = "linux";
          LEXICON_USERS = "ada";
        };
      };
    };

  # the wrapper's argument names are registration data. one placement hands
  # the entity to the evaluator and advertises it, the other applies it and
  # leaves it off
  testTwoBindersOneProjection = {
    expr = {
      native = argumentsOf (builtins.head whole.native.workstation.modules);
      den = argumentsOf (builtins.head whole.den.workstation.modules);
    };
    expected = {
      native = [
        "config"
        "host"
        "lib"
        "options"
        "pkgs"
      ];
      den = [
        "config"
        "lib"
        "options"
        "pkgs"
      ];
    };
  };

  testAnAbsentCapabilityEmitsNothing =
    let
      outcome = emitted ./fixtures/emission { };
    in
    {
      expr = {
        reported = codes outcome;
        inherit (outcome) halted;
      };
      expected = {
        reported = [
          "emit/missing-capability"
          "emit/missing-capability"
        ];
        halted = true;
      };
    };

  testACapabilityThatIsNotAFunctionIsNamedAsOne = {
    expr = codes (emitted ./fixtures/emission { systemEvaluator = 7; });
    expected = [
      "emit/malformed-capability"
      "emit/malformed-capability"
    ];
  };

  # a wrapper advertising a name nothing supplies is a defect in the
  # registration, and the registry reads it off the entry
  testABackendNamingAnUnsupplyableArgumentIsReported =
    let
      door = configured ./fixtures/emission capabilities;

      outcome = emission.run {
        inherit capabilities;
        backends = emission.backends.of [ miswired ];
      } (kata.load door.value).value;
    in
    {
      expr = {
        reported = codes outcome;
        notes = builtins.concatLists (map (given: given.notes) outcome.diagnostics);
      };
      expected = {
        reported = [ "emit/unsupplyable-context-argument" ];
        notes = [ "did you mean 'host'?" ];
      };
    };

  # a claim nobody can resolve is placed at the file the claim was written in
  testAnUnknownClaimIsPlacedAtTheFileItWasWrittenIn = {
    expr = {
      reported = codes claimed;
      placed = places claimed;
    };
    expected = {
      reported = [
        "kata/unknown-claimed-host"
        "kata/unknown-claimed-user"
      ];
      placed = [
        ''$."modules/stray.nix".furnish.users''
        ''$."modules/stray.nix".furnish.hosts''
      ];
    };
  };

  testAnUnknownClaimSuggestsTheNameItMeant = {
    expr = builtins.concatLists (map (given: given.notes) claimed.diagnostics);
    expected = [
      "did you mean 'ada'?"
      "did you mean 'workstation'?"
    ];
  };

  # a declaration with its places beside it and a registry with its claims
  # resolved are two types, and the door below each one reads which it holds
  testAnIndexedDeclarationIsNotAPreparedOne =
    let
      inherit (kata.internal) types;

      indexed = {
        declaration = { };
        origins = {
          stray = [ "modules/stray.nix" ];
        };
      };

      prepared =
        (kata.load {
          workstation = kata.host {
            declare = {
              system = "x86_64-linux";
              users = { };
            };
          };
        }).value;
    in
    {
      expr = {
        held = types.Indexed.check indexed;
        crossed = types.Prepared.check indexed;
        placed = types.Place.check [ "modules/stray.nix" ];
        deeper = types.Place.check [
          "modules/stray.nix"
          "furnish"
        ];
        handedOn = types.Prepared.check prepared;
      };
      expected = {
        held = true;
        crossed = false;
        placed = true;
        deeper = false;
        handedOn = true;
      };
    };

  # the names a resolved claim may hold are read off the registry it was
  # resolved against, and a claim the door cannot certify reaches no host
  testAClaimNamingAHostTheRegistryNeverHeldIsReported =
    let
      door = configured ./fixtures/emission capabilities;

      prepared = (kata.load door.value).value;

      strayed = prepared // {
        claims = lib.mapAttrs (
          _: held:
          lib.mapAttrs (_: _: {
            hosts = [ "nope" ];
            users = [ ];
          }) held
        ) prepared.claims;
      };

      outcome = emission.run { inherit capabilities; } strayed;
    in
    {
      expr = {
        reported = lib.unique (codes outcome);
        messages = lib.unique (map (given: given.message) outcome.diagnostics);
        inherit (outcome) halted;
      };
      expected = {
        reported = [ "emit/malformed-emission" ];
        messages = [
          "the claim on nixos in base must be a list of names the registry holds"
        ];
        halted = true;
      };
    };

  # a claims set that does not cover the registry beside it is a defect in
  # what the door was handed, and it is not the same defect as a claim that
  # cannot be certified
  testClaimsThatDoNotCoverTheRegistryAreReported =
    let
      door = configured ./fixtures/emission capabilities;

      prepared = (kata.load door.value).value;

      outcome = emission.run { inherit capabilities; } (prepared // { claims = { }; });
    in
    {
      expr = {
        reported = lib.unique (codes outcome);
        messages = lib.unique (map (given: given.message) outcome.diagnostics);
        inherit (outcome) halted;
      };
      expected = {
        reported = [ "emit/malformed-emission" ];
        messages = [
          "the claims beside the registry must be wide enough to cover nixos in base"
        ];
        halted = true;
      };
    };

  testAValueThatIsNoPreparedRegistryIsRefusedAtTheDoor = {
    expr = codes (emission.run { } 7);
    expected = [ "emit/malformed-emission" ];
  };

  testABackendHandingBackNoTargetIsReported =
    let
      door = configured ./fixtures/emission capabilities;

      outcome = emission.run {
        inherit capabilities;
        backends = emission.backends.of [ hollow ];
      } (kata.load door.value).value;
    in
    {
      expr = codes outcome;
      expected = [ "emit/malformed-emission" ];
    };

  # resolution writes its reports out of the places the fold indexed, so a
  # value arriving without them is sorted at that door too
  testADeclarationWithoutItsPlacesIsRefusedAtResolution = {
    expr = codes (krisis.run { } (kata.internal.resolve.run 7));
    expected = [ "kata/malformed-construction" ];
  };

  # a facet claiming one host is kept off the other, and a facet claiming
  # nobody is narrowed by nothing
  testAClaimKeepsAFacetOffAHostThatItDidNotName = {
    expr = {
      workstation = builtins.attrNames narrowed.native.workstation.carried;
      laptop = builtins.attrNames narrowed.native.laptop.carried;
    };
    expected = {
      workstation = [ "desktop" ];
      laptop = [ ];
    };
  };

  testTheDropInProjectsOneModulePerClass = {
    expr = {
      classes = builtins.attrNames denAspect;
      count = builtins.length denAspect.nixos;
      advertised = argumentsOf (builtins.head denAspect.nixos);
    };
    expected = {
      classes = [ "nixos" ];
      count = 1;
      advertised = [
        "config"
        "host"
        "lib"
        "options"
        "pkgs"
      ];
    };
  };

  testAnAspectMayNotCarryThisTreesIncludes = {
    expr = codes (reported (kata.entry { includes = [ (kata.entry { }) ]; }));
    expected = [ "emit/aspect-carries-includes" ];
  };

  testAnAspectMayNotCarryAClaim = {
    expr = codes (
      reported (
        kata.entry {
          furnish = {
            hosts = [ "workstation" ];
          };
        }
      )
    );
    expected = [ "emit/aspect-carries-claim" ];
  };
}
