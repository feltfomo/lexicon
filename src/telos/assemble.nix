# the assembly. it sits above emission because emission iterates hosts and
# nothing else, so an output belonging to no host has no row in that table
#
# TODO both sources of outputs are assembled here. a host declaration reaches
# the system its host declares, and a fleet declaration reaches every system
# it was handed, and the two meet in one list before anything is projected. a
# third source of outputs joins by producing sites in the declare stage below
# and by nothing else, because every stage after it reads sites and never the
# declarations they came from
{
  lib,
  fx,
  krisis,
  block,
  blocks,
  vocabulary,
  projected,
  types,
}:
let
  inherit (vocabulary) emit;
  inherit (fx) pipeline;

  # a host writes outputs for its own system, the fleet writes for every
  # system it was handed. which kind a site came from is what decides that,
  # and it is decided here and nowhere below
  sitesForHost =
    hosts: name: written:
    let
      found = lib.findFirst (host: host.name == name) null hosts;
    in
    if found == null then
      {
        problems = [
          (emit.unknown-declaring-host {
            at = [
              "hosts"
              name
            ];
            context.host = name;
          })
        ];
        sites = [ ];
      }
    else
      {
        problems = [ ];
        sites = map (blockName: {
          kind = "host";
          source = name;
          inherit (found) system;
          block = blockName;
          interior = written.${blockName};
        }) (builtins.attrNames written);
      };

  sitesForFleet =
    systems: written:
    lib.concatMap (
      blockName:
      map (system: {
        kind = "fleet";
        source = "fleet";
        inherit system;
        block = blockName;
        interior = written.${blockName};
      }) systems
    ) (builtins.attrNames written);

  # the declarations arrive as an argument and nothing above has read them,
  # so their shape is answered here
  heldAt =
    at: what: value:
    if builtins.isAttrs value then
      {
        problems = [ ];
        inherit value;
      }
    else
      {
        problems = [
          (emit.malformed-declaration {
            inherit at;
            context = {
              inherit what;
              expected = "an attrset";
            };
          })
        ];
        value = { };
      };

  gatheredFor =
    environment:
    let
      root = heldAt [ ] "the declarations handed to the output layer" environment.declarations;

      declaredHosts = heldAt [ "hosts" ] "the outputs declared by host" (root.value.hosts or { });

      declaredFleet = heldAt [ "fleet" ] "the outputs declared by the fleet" (root.value.fleet or { });

      byHost = map (
        name:
        let
          written = heldAt [
            "hosts"
            name
          ] "the outputs declared by ${name}" declaredHosts.value.${name};

          found = sitesForHost environment.hosts name written.value;
        in
        {
          problems = written.problems ++ found.problems;
          inherit (found) sites;
        }
      ) (builtins.attrNames declaredHosts.value);

      fleet = sitesForFleet environment.systems declaredFleet.value;
    in
    {
      problems =
        root.problems
        ++ declaredHosts.problems
        ++ declaredFleet.problems
        ++ lib.concatMap (one: one.problems) byHost;

      sites = lib.concatMap (one: one.sites) byHost ++ fleet;
    };

  # a block name is answered against the registry once, and legality is read
  # off the block rather than off the kind
  legalityOf =
    site:
    blocks.Registration.case {
      known =
        name:
        lib.optional (!builtins.elem name (blocks.allowedIn site.kind)) (
          emit.disallowed-output-block {
            at = [
              site.source
              name
            ];
            context = {
              inherit (site) kind;
              block = name;
            };
          }
        );

      unregistered = name: [
        (emit.unknown-output-block {
          at = [
            site.source
            name
          ];
          context.block = name;
          notes =
            let
              nearest = krisis.suggest name blocks.names;
            in
            lib.optional (nearest != null) "did you mean '${nearest}'?";
        })
      ];
    } (blocks.classify site.block);

  declareStage = pipeline.mkStage {
    name = "output-declare";
    outputType = types.Sites;
    transform =
      _:
      pipeline.bind pipeline.ask (
        environment:
        let
          gathered = gatheredFor environment;

          # the question is asked once and its answer decides both halves,
          # what is reported and what survives, so the two cannot drift
          answered = map (site: {
            inherit site;
            problems = legalityOf site;
          }) gathered.sites;

          kept = builtins.filter (one: one.problems == [ ]) answered;
        in
        pipeline.bind (fx.seq (gathered.problems ++ lib.concatMap (one: one.problems) answered)) (
          _: pipeline.pure (map (one: one.site) kept)
        )
      );
  };

  # the interior belongs to the block. the place it was written is installed
  # for the validator's extent, so the code a block reports lands at the path
  # the person wrote without the block touching a rendered path
  validateSite =
    site:
    let
      prefix = lib.optional (site.kind == "host") "hosts" ++ [
        site.source
        site.block
      ];
    in
    block.within prefix (
      blocks.byName.${site.block}.validate {
        emit = blocks.emitters.${site.block};
        value = site.interior;
      }
    );

  validateStage = pipeline.mkStage {
    name = "output-validate";
    inputType = types.Sites;
    outputType = types.Sites;
    transform = sites: pipeline.bind (fx.seq (map validateSite sites)) (_: pipeline.pure sites);
  };

  # the independent half is read once per site and says what each output in it
  # is, never what it builds to
  describedOf =
    site:
    let
      compiled = blocks.byName.${site.block}.compile.independent site.interior;
    in
    map (output: {
      inherit (site) system source block;
      inherit output;
      described = compiled.${output};
    }) (builtins.attrNames compiled);

  compileStage = pipeline.mkStage {
    name = "output-compile";
    inputType = types.Sites;
    outputType = types.Descriptions;
    transform = sites: pipeline.pure (lib.concatMap describedOf sites);
  };

  keyOf = one: "${one.system}/${one.block}/${one.output}";

  # two declarations reducing to one attribute path is refused with both named,
  # the way two files reducing to one name are. prefixing the host onto the
  # attribute would make the path unguessable from the source
  clashesIn =
    descriptions:
    let
      grouped = lib.groupBy keyOf descriptions;
    in
    lib.concatMap (
      key:
      let
        held = grouped.${key};
        one = builtins.head held;
      in
      lib.optional (builtins.length held > 1) {
        inherit key;
        origins = lib.sort (a: b: a < b) (map (each: each.source) held);
        inherit (one) block system output;
      }
    ) (builtins.attrNames grouped);

  collideStage = pipeline.mkStage {
    name = "output-collide";
    inputType = types.Descriptions;
    outputType = types.Descriptions;
    transform =
      descriptions:
      let
        clashes = clashesIn descriptions;

        # the key that decided the clash is the key that decides the removal
        refused = map (held: held.key) clashes;
      in
      pipeline.bind (fx.seq (
        map (
          held:
          emit.output-name-collision {
            at = [
              held.block
              held.system
              held.output
            ];
            context = {
              inherit (held) output system;
              sources = builtins.concatStringsSep " and " held.origins;
            };
          }
        ) clashes
      )) (_: pipeline.pure (builtins.filter (one: !builtins.elem (keyOf one) refused) descriptions));
  };

  # the dependent half needs a package set, so it is applied per system and
  # only where one was handed in
  builtFor =
    packageSets: system: blockName: held:
    let
      described = lib.listToAttrs (map (one: lib.nameValuePair one.output one.described) held);
    in
    blocks.byName.${blockName}.compile.dependent { pkgs = packageSets.${system}; } described;

  # what leaves here is the standard flake surface, whose shape belongs to nix
  # and not to lexicon, so there is nothing truthful to check it against
  projectStage = pipeline.mkStage {
    name = "output-project";
    inputType = types.Descriptions;
    transform =
      descriptions:
      pipeline.bind (pipeline.asks (environment: environment.packageSets)) (
        packageSets:
        let
          missing = lib.unique (
            map (one: one.system) (builtins.filter (one: !(packageSets ? ${one.system})) descriptions)
          );

          supplied = builtins.filter (one: packageSets ? ${one.system}) descriptions;

          # a block with no entry in the table is lexicon's own and reaches no
          # standard attribute, which is what omitting it from the table means
          bySystem = lib.groupBy (one: one.system) (builtins.filter (one: projected ? ${one.block}) supplied);

          surfaceFor =
            system:
            let
              byBlock = lib.groupBy (one: one.block) bySystem.${system};
            in
            lib.foldl' (
              gathered: blockName:
              lib.recursiveUpdate gathered {
                ${projected.${blockName}}.${system} = builtFor packageSets system blockName byBlock.${blockName};
              }
            ) { } (builtins.attrNames byBlock);
        in
        pipeline.bind
          (fx.seq (
            map (
              system:
              emit.missing-package-set {
                at = [ system ];
                context.system = system;
              }
            ) missing
          ))
          (
            _:
            pipeline.pure (
              lib.foldl' (gathered: system: lib.recursiveUpdate gathered (surfaceFor system)) { } (
                builtins.attrNames bySystem
              )
            )
          )
      );
  };

  stages = [
    declareStage
    validateStage
    compileStage
    collideStage
    projectStage
  ];

  # the environment is installed for this assembly only, so the krisis effects
  # the stages send rotate outward to whatever policy the caller opened
  run =
    {
      declarations,
      hosts,
      systems,
      packageSets,
    }:
    krisis.gate (
      fx.effects.scope.run {
        handlers = fx.effects.reader.handler;
        state = {
          inherit
            declarations
            hosts
            systems
            packageSets
            ;
        };
      } (pipeline.compose stages null)
    );
in
{
  inherit run;
}
