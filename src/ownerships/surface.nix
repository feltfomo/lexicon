# _lib/ownerships/surface.nix
#
# the surface aspects author against. its only job is to erase the ceremony the
# old scoped path needed -- instead of `{ host, user } - let for = scoped.for ...`
# an aspect hands `resolve` a plain list of self-labeling units, and the build
# context is read in here, not by the author. a unit carries its owners as
# ordinary keys (hosts / users / excepthosts / exceptusers / when); whatever's
# left is its config. untagged means globally owned. this is a thin translator
# onto the engine's claim tree and holds no resolution logic of its own, so every
# nesting and conflict guarantee still comes from the engine.
#
# every door is one point in a four-axis product -- scope x projection x strict x
# merge -- and `resolverFor` is the only body. the tables at the bottom name the
# points worth exporting, so adding or dropping a door is a row, not a function.
{
  lib,
  krisis,
  axiom,
  descriptors ? null,
  relations ? null,
}:
let
  engine = import ./engine.nix { inherit lib krisis axiom; };
  axes = import ./axes.nix { inherit lib krisis axiom; };
  inherit (axiom) schema validation;

  unitProblem = krisis.mkDiagnosticFactory {
    severity = "error";
    codePrefix = "ownerships";
  };

  reporter = krisis.mkReporter { formatDiagnostic = krisis.renderPlain; };

  finish = validation.finish reporter.fail;

  failUnit = reporter.failOne;

  # a missing or non-string label is usually what the error is about, so it
  # can't name the unit.
  labelOf =
    unit:
    lib.optionalAttrs (builtins.isAttrs unit && unit ? label && builtins.isString unit.label) {
      primary.label = unit.label;
    };

  descriptorSet = axes.compileDescriptors (
    if descriptors == null then axes.descriptors else descriptors
  );
  axisDescriptors = descriptorSet.descriptors;
  relationRegistrations = if relations == null then axes.relations else relations;
  resolveLib = import ./resolve.nix {
    inherit lib krisis axiom;
    compiled = descriptorSet;
    relations = relationRegistrations;
  };
  mergeLib = import ./merge.nix { inherit lib krisis axiom; };
  matrixLib = import ./matrix.nix { inherit lib krisis axiom; };

  defaultMerge = (mergeLib.mkMerge { }).mergeTracked;

  # descriptor key order is stable because it also controls which malformed key
  # an author sees first when several are wrong.
  inherit (descriptorSet) claimKeys;
  # label/source are reserved like `value`/`children`, optional
  # plain-string identification for diagnostics, never config, never merged --
  # they ride the leaf as siblings of `value`, and `strip` only ever pulls
  # `.value`, so they're dropped before merge with no extra work.
  carriedKeys = [
    "children"
    "label"
    "source"
    "mergeProfile"
  ];
  carriedAttrs = lib.genAttrs carriedKeys (_: null);
  reserved = claimKeys ++ [ "value" ] ++ carriedKeys;

  # ownership keys are read by name off a unit's top level, so a config value
  # sitting on a reserved key would be silently swallowed as a claim. the one
  # realistic collision is a nixos `users` attrset landing where the `users`
  # name-list belongs, so shape-check the claim keys and fail at author time
  # rather than resolve something the author never meant.
  # open, because everything that isn't a reserved key is the unit's config and
  # this schema has no business ruling on its shape
  unitSchema = schema.compile {
    allowUnknown = true;
    onRecord =
      value:
      unitProblem {
        code = "unit-shape";
        message = "a unit must be an attribute set; got ${builtins.typeOf value}";
      };
    order = [
      "children"
      "value"
      "label"
      "source"
    ];
    fields = {
      children = {
        validate = value: builtins.isList value && lib.all builtins.isAttrs value;
        onInvalid =
          record: _value:
          unitProblem (
            {
              code = "unit-children";
              message = "'children' must be a list of unit attribute sets";
            }
            // labelOf record
          );
      };
      value = {
        validate = builtins.isAttrs;
        onInvalid =
          record: value:
          unitProblem (
            {
              code = "unit-value";
              message = "'value' must be an attribute set; got ${builtins.typeOf value}";
            }
            // labelOf record
          );
      };
      label = {
        validate = builtins.isString;
        onInvalid =
          _record: value:
          unitProblem {
            code = "unit-label";
            message = "'label' must be a plain string; got ${builtins.typeOf value}";
          };
      };
      source = {
        validate = builtins.isString;
        onInvalid =
          record: value:
          unitProblem (
            {
              code = "unit-source";
              message = "'source' must be a plain string; got ${builtins.typeOf value}";
            }
            // labelOf record
          );
      };
    };
  };

  # claim keys stay a separate earlier stage because their errors are the
  # descriptor author's own strings, not krisis records
  checkShape =
    unit:
    if !builtins.isAttrs unit then
      failUnit (unitProblem {
        code = "unit-shape";
        message = "a unit must be an attribute set; got ${builtins.typeOf unit}";
      })
    else
      let
        checkedClaims = axes.validateUnitWith descriptorSet.authorKeys unit;
        # a value block routes unambiguously only when it's the sole non-reserved
        # content on the unit -- claims and children still narrow around it
        # exactly as they do around inline config, so only a genuine leftover
        # inline key next to `value` is the ambiguous case.
        leftover = removeAttrs unit reserved;
        diagnostics = validation.collect [
          (unitSchema unit).diagnostics
          (validation.optional (unit ? value && leftover != { }) (
            unitProblem (
              {
                code = "unit-mixed-value";
                message = "a unit cannot mix a 'value' block with inline config keys (${lib.concatStringsSep ", " (builtins.attrNames leftover)}) -- route everything through 'value' or drop it";
              }
              // labelOf unit
            )
          ))
        ];
      in
      builtins.seq checkedClaims (finish (validation.fromDiagnostics diagnostics unit));

  claimOf = axes.claimOf axisDescriptors;

  # the payload riding this leaf is the escape-hatch block verbatim when the unit
  # used one, otherwise whatever's left after stripping the reserved keys --
  # same rule as before the hatch existed. two different `value`s share the
  # word, not the meaning. `checked.value` is the author-facing escape-hatch
  # key, `payload` becomes the engine leaf's `value` field (the config every
  # leaf carries, hatch or not) -- don't conflate them.
  translateWith =
    profileNames: unit:
    let
      checked = checkShape unit;
      profileChecked =
        if profileNames == null || !(checked ? mergeProfile) then
          checked
        else if !builtins.isString checked.mergeProfile then
          failUnit (unitProblem {
            code = "unit-merge-profile";
            message = "'mergeProfile' must be a plain string; got ${builtins.typeOf checked.mergeProfile}";
          })
        else if !(builtins.elem checked.mergeProfile profileNames) then
          failUnit (
            unitProblem (
              {
                code = "unit-merge-profile-unknown";
                message = "unknown merge profile '${checked.mergeProfile}'${axes.suggestionFor profileNames checked.mergeProfile}";
              }
              // labelOf checked
            )
          )
        else
          checked;
      payload = profileChecked.value or (removeAttrs profileChecked reserved);
      unitIdentity = engine.identifyUnit {
        unit = profileChecked;
        label = profileChecked.label or null;
        source = profileChecked.source or null;
      };
      contextualProfile = builtins.foldl' (
        result: key:
        if result ? ${key} && builtins.isFunction result.${key} then
          result
          // {
            ${key} =
              ctx:
              krisis.withErrorContext "ownerships: while evaluating '${key}' predicate for ${unitIdentity}" (
                profileChecked.${key} ctx
              );
          }
        else
          result
      ) profileChecked claimKeys;
      claim = claimOf contextualProfile;
      children = map (translateWith profileNames) (profileChecked.children or [ ]);
      carriesDeclaration = lib.any (key: profileChecked ? ${key}) (
        claimKeys
        ++ [ "value" ]
        ++ [
          "label"
          "source"
          "mergeProfile"
        ]
      );
      valid = builtins.deepSeq claim (
        if payload == { } && children == [ ] && carriesDeclaration then
          failUnit (unitProblem {
            code = "unit-metadata-only";
            message = "${unitIdentity} has ownership metadata but no config or children";
          })
        else
          true
      );
    in
    # the carried keys ride through as one projection; `children` is reapplied
    # last because the translated tree replaces the authored one.
    builtins.seq valid (
      {
        inherit claim;
      }
      // lib.optionalAttrs (payload != { }) { value = payload; }
      // builtins.intersectAttrs carriedAttrs profileChecked
      // lib.optionalAttrs (profileChecked ? children) { inherit children; }
    );

  translate = translateWith null;

  # a system-scope resolve binds a host but no user (ctx.user = null), so a
  # `users` / `exceptusers` claim anywhere in the tree can never own anything --
  # a host-wide slice has no user to narrow to. reject that when the units are
  # handed in, before resolve runs, naming every offending key and its value.
  # the engine's resolve-time missing-ctx throw still backstops a miss here, so
  # this is a clearer, earlier message rather than the only line of defense.
  scopeGuard =
    scope: units:
    let
      violations = axes.scopeViolationsFor axisDescriptors scope units;
    in
    if violations == [ ] then true else throw (lib.concatStringsSep "\n" violations);

  # matrix contexts differ only in which entity names the roster projection
  # yields, so the scope picks the constructor and the default ctx together.
  # hostname is the canonical host id; bind it as host.id so the generic
  # memberof reads it directly instead of re-deriving (and double-prefixing) a
  # system from a bare name.
  matrixScopes = {
    user = {
      contexts = matrixLib.mkUserContexts;
      defaultContext =
        { hostName, userName }:
        {
          host.id = hostName;
          user.name = userName;
        };
    };
    system = {
      contexts = matrixLib.mkSystemContexts;
      defaultContext = { hostName }: { host.id = hostName; };
    };
  };

  # the one resolver body. scope decides which axes a unit may narrow on,
  # projection decides what comes back, strict adds roster validation of the
  # build ctx, and profileArgs swaps the merge and the profile vocabulary the
  # translator accepts.
  resolverFor =
    {
      roster,
      base ? resolveLib.engineArgsFor roster,
      scope ? "user",
      projection ? "value",
      strict ? false,
      profileArgs ? null,
    }:
    let
      profiles = if profileArgs == null then null else profileArgs.profiles or mergeLib.builtinProfiles;
      merge =
        if profiles == null then
          defaultMerge
        else
          (mergeLib.mkMerge (profileArgs // { inherit profiles; })).mergeTracked;
      translateUnit = if profiles == null then translate else translateWith (builtins.attrNames profiles);
      tree = units: { children = map translateUnit units; };
      guarded = units: value: builtins.seq (scopeGuard scope units) value;
      # strict validation runs before the body, not from inside the ctx thunk. a
      # globally owned unit narrows on nothing and so never demands ctx, which
      # meant an unrostered host resolved without the roster check ever running.
      withContext =
        rawCtx: body:
        let
          ctx = axes.contextFor base.registry rawCtx;
        in
        if strict then builtins.seq (resolveLib.validateCtxWith base ctx) (body ctx) else body ctx;
      pipelineArgs = ctx: {
        inherit (base) registry stages;
        inherit merge ctx;
      };
      projections = {
        value =
          units:
          guarded units (rawCtx: withContext rawCtx (ctx: engine.resolve (pipelineArgs ctx) (tree units)));
        trace =
          units:
          guarded units (rawCtx: withContext rawCtx (ctx: engine.trace (pipelineArgs ctx) (tree units)));
        # the ctx-independent half runs once when the units are handed in; the
        # returned function is only ctx demand, select, survivors, and merge.
        prepared =
          units:
          guarded units (
            let
              half = engine.prepare {
                inherit (base) registry stages;
                inherit merge;
              } (tree units);
            in
            rawCtx: withContext rawCtx (ctx: (engine.applyPrepared half ctx).value)
          );
        matrix =
          {
            units,
            contextFor ? matrixScopes.${scope}.defaultContext,
          }:
          guarded units (
            matrixLib.report {
              inherit roster scope;
              inherit (base) registry stages;
              contexts = matrixScopes.${scope}.contexts {
                inherit roster;
                contextFor = names: axes.contextFor base.registry (contextFor names);
              };
              unit = tree units;
            }
          );
      };
    in
    projections.${projection}
      or (throw "ownerships: unknown resolver projection '${projection}'${axes.suggestionFor (builtins.attrNames projections) projection}");

  # the exported points of the product. a combination that isn't here is one
  # row away, and `resolverFor` reaches any of them directly.
  doorTable = {
    resolve = { };
    resolveSystem = {
      scope = "system";
    };
    trace = {
      projection = "trace";
    };
    systemTrace = {
      scope = "system";
      projection = "trace";
    };
    prepared = {
      projection = "prepared";
    };
    systemPrepared = {
      scope = "system";
      projection = "prepared";
    };
    matrix = {
      projection = "matrix";
    };
    systemMatrix = {
      scope = "system";
      projection = "matrix";
    };
    strict = {
      strict = true;
    };
    systemStrict = {
      scope = "system";
      strict = true;
    };
  };

  # bind a roster once and take every door off one compiled base. a fleet
  # normally opens several doors over the same roster; before this each one
  # compiled its own registry, stages, and descriptor set from that roster.
  mkResolvers =
    roster:
    let
      base = resolveLib.engineArgsFor roster;
      door = args: resolverFor (args // { inherit roster base; });
    in
    lib.mapAttrs (_: door) doorTable
    // {
      resolverFor = door;
      profiled = profileArgs: door { inherit profileArgs; };
      systemProfiled =
        profileArgs:
        door {
          inherit profileArgs;
          scope = "system";
        };
    };

  # the mkResolve* names aspects and tests already bind, generated from the same
  # table so there is no second implementation to keep in step.
  legacyDoors = {
    mkResolve = "resolve";
    mkResolveSystem = "resolveSystem";
    mkResolveTrace = "trace";
    mkResolveSystemTrace = "systemTrace";
    mkResolvePrepared = "prepared";
    mkResolveSystemPrepared = "systemPrepared";
    mkResolveMatrix = "matrix";
    mkResolveSystemMatrix = "systemMatrix";
    mkResolveStrict = "strict";
    mkResolveSystemStrict = "systemStrict";
  };

  doors = lib.mapAttrs (
    _: name: roster:
    (mkResolvers roster).${name}
  ) legacyDoors;

  mkResolveProfiled = profileArgs: roster: (mkResolvers roster).profiled profileArgs;
  mkResolveSystemProfiled = profileArgs: roster: (mkResolvers roster).systemProfiled profileArgs;
in
doors
// {
  inherit
    mkResolvers
    resolverFor
    mkResolveProfiled
    mkResolveSystemProfiled
    translate
    claimKeys
    ;
  # callers that build their own enclosing unit need to narrow a claim into the
  # scope they are about to resolve in, or scopeGuard rejects the wrapper for
  # carrying an axis the scope cannot bind.
  projectClaims = axes.projectClaims axisDescriptors;
  inherit (resolveLib) define toRoster mkRoster;
}
