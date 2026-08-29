# _lib/ownerships/resolve.nix
#
# public entry. axis descriptors and relation registrations turn one roster
# into the engine registry and leaf-stage set, so standalone and den-backed
# callers share the same path.
{
  lib,
  krisis,
  axiom,
  descriptors ? null,
  relations ? null,
  # a caller that already compiled the descriptor set hands it in so the whole
  # subsystem validates descriptors once. surface.nix used to compile its own,
  # which meant three doors on one roster paid for three identical compiles.
  compiled ? null,
}:
let
  engine = import ./engine.nix { inherit lib krisis axiom; };
  axes = import ./axes.nix { inherit lib krisis axiom; };
  descriptorSet =
    if compiled != null then
      compiled
    else
      axes.compileDescriptors (if descriptors == null then axes.descriptors else descriptors);
  axisDescriptors = descriptorSet.descriptors;
  relationRegistrations = axes.validateRelations axisDescriptors (
    if relations == null then axes.relations else relations
  );
  mergeLib = import ./merge.nix { inherit lib krisis axiom; };
  rosterLib = import ./roster.nix {
    inherit lib krisis axiom;
    descriptors = axisDescriptors;
  };

  defaultMerge = (mergeLib.mkMerge { }).mergeTracked;

  engineArgsFor =
    roster:
    let
      registry = axes.registryForCompiled descriptorSet roster;
      relationStages = map (relation: {
        inherit (relation) name;
        view = "leaf";
        run = engine.mkRelationCheck relation;
      }) (axes.relationsFor relationRegistrations roster);
    in
    {
      inherit registry;
      stages = [
        # alias ambiguity is rejected before satisfiability and relations so a
        # bare alias spanning multiple canonical members fails loud with its own
        # wording rather than surfacing as a generic unknown-name/disjoint error.
        {
          view = "leaf";
          run = axes.aliasValidationCheck;
        }
        {
          view = "leaf";
          run = engine.satisfiableCheck;
        }
      ]
      ++ relationStages
      ++ axes.leafStagesFor axisDescriptors roster;
    };

  validateCtxWith =
    args: ctx:
    let
      claim = (engine.topClaim args.registry) // axes.ctxClaimFor axisDescriptors ctx;
      label = "standalone ctx ${axes.ctxLabelFor axisDescriptors ctx}";
      leaf = {
        inherit claim label;
        value = { };
      };
    in
    builtins.seq (engine.check args.stages args.registry [ leaf ]) ctx;

  # the roster form is the same check with the engine args built on the spot,
  # for callers that hold a roster rather than a compiled base.
  validateRosterCtx = roster: validateCtxWith (engineArgsFor roster);

  resolveWith =
    {
      roster,
      ctx,
      merge ? defaultMerge,
    }:
    unit:
    let
      args = engineArgsFor roster;
    in
    engine.resolve {
      inherit (args) registry stages;
      inherit ctx merge;
    } unit;
in
{
  inherit (rosterLib) define toRoster mkRoster;
  inherit
    resolveWith
    engineArgsFor
    validateRosterCtx
    validateCtxWith
    descriptorSet
    ;
}
