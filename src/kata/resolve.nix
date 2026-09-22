# claim resolution. a claim is a list of names a facet applies to, and what
# leaves here holds the resolved claims and no longer holds the places
{
  lib,
  fx,
  t,
  krisis,
  arrows,
  vocabulary,
  claims,
  blocks,
  kinds,
  types,
}:
let
  inherit (vocabulary) emit;
  inherit (arrows) sum;
  inherit (fx) pipeline;

  inherit (claims) keys;

  # the kinds that hold their own schema are the ones a claim names, and the
  # rest are the ones that carry blocks for a claim to sit in
  carriers = map (kind: kind.collection) (builtins.filter (kind: !kind.declare) kinds);

  # the names a claim of one key may draw from are read off the declaration
  # in hand. nix-effects types/refinement and types/dependent, docs
  # buildhash 1xxh55icdl0xpinnn69wz20wykrhjwds
  Known =
    universe:
    t.refined "KnownNames" (t.listOf t.String) (
      given: builtins.all (name: builtins.elem name universe) given
    );

  # one arm per claim key, read off the kind registry
  Claim = sum (lib.genAttrs keys (_: t.Attrs));

  strings = value: builtins.isList value && builtins.all builtins.isString value;

  # the fold writes a collection only when something landed in it
  held = declaration: collection: declaration.${collection} or { };

  hostNames = declaration: builtins.attrNames (held declaration "hosts");

  userNames =
    declaration:
    lib.concatMap (host: builtins.attrNames (host.users or { })) (
      builtins.attrValues (held declaration "hosts")
    );

  # a claim of the wrong shape was reported by the fold, so everything
  # gathered here is a list of names
  gathered =
    at: value:
    lib.concatMap (
      key:
      lib.optional (value ? ${key} && strings value.${key}) (
        Claim.inject.${key} {
          inherit key at;
          names = value.${key};
        }
      )
    ) keys;

  # the descent is the one the block declared. a node the route reaches that
  # is the wrong shape to walk was reported by the block's own validator
  descend =
    route: at: value:
    if !builtins.isAttrs value then
      [ ]
    else if route == [ ] then
      gathered at value
    else
      let
        key = builtins.head route;
        rest = builtins.tail route;
      in
      if !(value ? ${key}) || !builtins.isList value.${key} then
        [ ]
      else
        lib.concatLists (
          lib.imap0 (
            index: entry:
            descend rest (
              at
              ++ [
                key
                index
              ]
            ) entry
          ) value.${key}
        );

  # a block nobody registered declares no route, and the fold reported the
  # block itself
  routesOf =
    interiors: name:
    blocks.Registration.case {
      known =
        block:
        lib.concatMap (route: descend route [ block ] interiors.${block}) blocks.byName.${block}.claimable;
      unregistered = _: [ ];
    } (blocks.classify name);

  note =
    universe: name:
    let
      nearest = krisis.suggest name universe;
    in
    lib.optional (nearest != null) "did you mean '${nearest}'?";

  sifted = universe: reporter: claim: {
    inherit (claim) key at;
    known = builtins.filter (name: builtins.elem name universe) claim.names;
    reports = map reporter (builtins.filter (name: !builtins.elem name universe) claim.names);
  };

  # the place is the file the claim was written in
  resolveOne =
    place: declaration: claim:
    Claim.case {
      hosts =
        payload:
        let
          universe = hostNames declaration;
        in
        sifted universe (
          name:
          emit.unknown-claimed-host {
            at = place ++ payload.at ++ [ payload.key ];
            context = {
              host = name;
            };
            notes = note universe name;
          }
        ) payload;

      users =
        payload:
        let
          universe = userNames declaration;
        in
        sifted universe (
          name:
          emit.unknown-claimed-user {
            at = place ++ payload.at ++ [ payload.key ];
            context = {
              user = name;
            };
            notes = note universe name;
          }
        ) payload;
    } claim;

  # a claim written at the top of a block narrows where that block goes. a
  # claim deeper inside narrows something the block owns, and whatever reads
  # the block honours it
  reachOf =
    block: items:
    lib.genAttrs keys (
      key: lib.concatMap (item: lib.optionals (item.at == [ block ] && item.key == key) item.known) items
    );

  resolveEntry =
    declaration: place: entry:
    let
      names = builtins.attrNames entry.blocks;
      items = map (resolveOne place declaration) (lib.concatMap (routesOf entry.blocks) names);
    in
    {
      reports = lib.concatMap (item: item.reports) items;
      reach = lib.genAttrs (builtins.filter blocks.has names) (block: reachOf block items);
    };

  entriesOf =
    indexed:
    lib.concatMap (
      collection:
      lib.mapAttrsToList (
        name: entry: lib.nameValuePair name (resolveEntry indexed.declaration indexed.origins.${name} entry)
      ) (held indexed.declaration collection)
    ) carriers;

  siftStage = pipeline.mkStage {
    name = "claim-sift";
    transform =
      indexed:
      let
        resolved = entriesOf indexed;
      in
      pipeline.bind (fx.seq (lib.concatMap (entry: entry.value.reports) resolved)) (
        _: pipeline.pure resolved
      );
  };

  settleStage = pipeline.mkStage {
    name = "claim-settle";
    transform =
      resolved:
      pipeline.bind (pipeline.asks (indexed: indexed.declaration)) (
        declaration:
        pipeline.pure {
          inherit declaration;
          claims = lib.listToAttrs (map (entry: entry // { value = entry.value.reach; }) resolved);
        }
      );
  };

  stages = [
    siftStage
    settleStage
  ];

  # a declaration without its places is a value resolution has no report to
  # write from, and what arrives is sorted once here
  Handed = sum {
    indexed = t.Attrs;
    foreign = t.Any;
  };

  handedOf =
    value:
    if types.Indexed.check value then Handed.inject.indexed value else Handed.inject.foreign value;

  # the indexed declaration is the environment for this walk only. the gate
  # keeps an unresolvable claim off the path a target is emitted from
  walk =
    indexed:
    fx.effects.scope.run {
      handlers = fx.effects.reader.handler;
      state = indexed;
    } (pipeline.compose stages indexed);

  run =
    value:
    krisis.gate (
      Handed.case {
        indexed = walk;

        foreign =
          _:
          fx.bind
            (emit.malformed-construction {
              at = [ ];
              context = {
                what = "what the fold hands resolution";
                expected = "a declaration with the place of every value beside it";
              };
              notes = [ ];
            })
            (
              _:
              fx.pure {
                declaration = { };
                claims = { };
              }
            );
      } (handedOf value)
    );
in
{
  inherit run Known;
}
