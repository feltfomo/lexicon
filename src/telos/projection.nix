# a lexicon-declared output is a standard flake output plus the provenance
# lexicon needs, and the standard output is recovered by forgetting that
# provenance rather than by rebuilding it. the forgetting map and the
# elaboration of the enriched record both come from the ornament library, so
# nothing here walks a value by hand
{
  lib,
  fx,
  krisis,
}:
let
  H = fx.types.hoas;
  G = fx.types.generic;

  # every output shape shares the two fields a flake output is keyed by and
  # differs only in the payload a caller wants to carry
  outputDatatype =
    name: payload:
    H.datatype name [
      (H.con "output" (
        [
          (H.field "name" H.string)
          (H.field "system" H.string)
        ]
        ++ payload
      ))
    ];

  Output = outputDatatype "Output" [ ];

  # the shape a real checks entry has
  Entry = outputDatatype "Entry" [ (H.field "drv" H.derivation) ];

  # the documented rescue for a payload the kernel will not hold onto, tried
  # here and failing the same way on nix-effects 0.16.0
  ThunkEntry = outputDatatype "ThunkEntry" [ (H.field "drv" (H.thunk H.derivation)) ];

  # the keeps are read off the base rather than restated, so a field added to
  # a base cannot silently fall out of the ornament
  specFor = base: {
    name = "Declared${base.name}";
    constructors.output.fields =
      map (field: { keep = field.name; }) (G.datatype.fields (G.datatype.constructorByName base "output"))
      ++ [
        {
          insert = "origin";
          type = H.string;
        }
      ];
  };

  synth.constructors.output.fields.origin = ctx: "lexicon/${ctx.baseRecord.name}";

  declaredFrom =
    base:
    G.ornaments.functional {
      inherit base synth;
      spec = specFor base;
    };

  declared = declaredFrom Output;
  declaredEntry = declaredFrom Entry;
  declaredThunkEntry = declaredFrom ThunkEntry;

  baseOf = ornament: ornament.meta.base;

  # the forward direction. review elaborates and type-checks the record
  # before section ever sees it
  sectionWith =
    ornament: builder: record:
    builder H.tt (G.value.review (baseOf ornament).T record);

  section = ornament: sectionWith ornament ornament.section;

  # the backward direction, over a value the kernel produced
  project =
    ornament: value:
    G.value.view (baseOf ornament).T (G.ornaments.forget ornament.meta.ornamented value);

  # the same morphism over an ordinary record, which is the only route left
  # to a payload the kernel keeps opaque
  projectRecord = ornament: record: G.ornaments.forget ornament.meta.ornamented record;

  # the generic synthesis route builds the section but drops the law bundle on
  # nix-effects 0.16.0 src/tc/generic/ornaments.nix, so an ornament carrying
  # laws is assembled at the hoas layer from the section that route produced,
  # and the law runs against the builder the kernel is about to use
  withRoundTripLaw =
    ornament: table:
    H.functionalOrnament {
      inherit (ornament)
        ornament
        chooseIndex
        section
        indexProof
        ;
      laws.checks.forget-section =
        F: builtins.all (record: project ornament (sectionWith ornament F.section record) == record) table;
    };

  vocabulary = krisis.vocabulary {
    namespace = "telos";
    codes = {
      output-builder-missing = {
        message = { rendered, ... }: "declared output field ${rendered.field} has no builder";
        help = "give the inserted field a builder under synth.constructors";
      };

      case-arm-missing = {
        message = { rendered, ... }: "no arm for constructor ${rendered.constructor}";
      };

      case-arm-unknown = {
        message = { rendered, ... }: "arm ${rendered.arm} is not a declared constructor";
      };
    };
  };

  validateSpec =
    args:
    G.ornaments.validateFunctional (
      {
        base = Output;
        spec = specFor Output;
      }
      // args
    );

  # the kernel record is the evidence and keeps its own path. only the code
  # is renamed into lexicon's vocabulary, and only the one code a missing
  # builder produces
  reportSpec =
    args:
    let
      missingBuilders = builtins.filter (
        diagnostic: diagnostic.code == "functional.missing-builder"
      ) (validateSpec args).diagnostics;
    in
    fx.seq (
      map (
        diagnostic:
        vocabulary.emit.output-builder-missing {
          at = diagnostic.path;
          context.field = lib.last diagnostic.path;
        }
      ) missingBuilders
    );

  # the declared constructor set comes from the datatype, so a constructor
  # with no arm is caught before a value is dispatched rather than at the
  # call that falls off the end
  caseOf =
    { datatype, arms }:
    value:
    let
      declaredConstructors = map (con: con.name) (G.datatype.datatypeInfo datatype).constructors;

      missing = builtins.filter (name: !(arms ? ${name})) declaredConstructors;

      unknown = builtins.filter (name: !(builtins.elem name declaredConstructors)) (
        builtins.attrNames arms
      );

      problems =
        map (
          name:
          vocabulary.emit.case-arm-missing {
            at = [ "arms" ];
            context.constructor = name;
          }
        ) missing
        ++ map (
          name:
          vocabulary.emit.case-arm-unknown {
            at = [
              "arms"
              name
            ];
            context.arm = name;
          }
        ) unknown;
    in
    if problems == [ ] then fx.pure (arms.${value._con} value) else krisis.gate (fx.seq problems);
in
{
  inherit
    Output
    Entry
    ThunkEntry
    declared
    declaredEntry
    declaredThunkEntry
    section
    project
    projectRecord
    withRoundTripLaw
    vocabulary
    validateSpec
    reportSpec
    caseOf
    ;
}
