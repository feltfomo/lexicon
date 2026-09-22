# composition. an includes list is followed to everything it reaches, a
# declaration pulled in three ways lands once, a cycle is named instead of
# walked forever, and every value leaves here beside the places its payload
# is written at
{
  lib,
  fx,
  t,
  arrows,
  vocabulary,
  construct,
  kinds,
}:
let
  inherit (vocabulary) emit;
  inherit (arrows) sum traverse;

  kindNamed = name: lib.findFirst (kind: kind.name == name) null kinds;

  # an included value is sorted once where it arrives, so nothing below asks
  # what it is again
  Included = sum {
    foreign = t.Any;
    anonymous = t.Attrs;
    named = t.Attrs;
  };

  # a seed arrives under the key a caller wrote, and one that is not a
  # construction is left exactly where it is
  Seeded = sum {
    opaque = t.Any;
    rooted = t.Attrs;
  };

  Input = sum {
    plain = t.Any;
    set = t.Attrs;
  };

  # one include edge, read off the kind of the value holding the list and the
  # kind of the value it reached
  Edge = sum {
    beside = t.Attrs;
    within = t.Attrs;
    misplaced = t.Attrs;
  };

  # where a gathered value's payload is written. a kind naming a parent is
  # written inside each value that included it and nowhere else
  Residence = sum {
    rooted = t.Attrs;
    nested = t.Attrs;
    unplaced = t.Attrs;
    unrecognised = t.Any;
  };

  nameOf = origin: lib.removeSuffix ".nix" (baseNameOf origin);

  classify =
    value:
    if !construct.isTagged value then
      Included.inject.foreign value
    else if (construct.read value).origin == null then
      Included.inject.anonymous value
    else
      Included.inject.named value;

  seedOf =
    value: if construct.isTagged value then Seeded.inject.rooted value else Seeded.inject.opaque value;

  inputOf =
    values: if builtins.isAttrs values then Input.inject.set values else Input.inject.plain values;

  keyFor =
    name: value:
    let
      held = construct.read value;
    in
    if held.origin == null then name else held.origin;

  parentOf = described: if described == null then null else described.parent;

  # the child's own kind names the kind it belongs to, and the value holding
  # the includes list either is that kind or is not
  edgeOf =
    holder: name: held:
    let
      described = kindNamed held.kind;
      holding = kindNamed holder.kind;
      parent = parentOf described;
    in
    if parent == null then
      Edge.inject.beside { inherit name; }
    else if parent == holder.kind && holding != null then
      Edge.inject.within {
        inherit name;
        into = [
          holding.collection
          holder.name
          described.container
        ];
      }
    else
      Edge.inject.misplaced {
        inherit name parent;
        inherit (held) kind;
      };

  cycle =
    trail: key:
    emit.include-cycle {
      at = trail;
      context = {
        cycle = builtins.concatStringsSep " -> " (trail ++ [ key ]);
      };
    };

  misplacement =
    holder: wrong:
    emit.misplaced-include {
      at = [ holder.name ];
      context = {
        entry = holder.name;
        inherit (wrong) kind name parent;
      };
    };

  homeless =
    entry:
    emit.unplaced-declaration {
      at = entry.place;
      context = {
        inherit (entry) kind name parent;
      };
    };

  gathering = {
    held = { };
    links = [ ];
    refused = [ ];
  };

  absorb =
    trail: gathered: key: name: value:
    if builtins.elem key trail then
      fx.bind (cycle trail key) (_: fx.pure gathered)
    else if gathered.held ? ${key} then
      fx.pure gathered
    else
      let
        held = construct.read value;
        deeper = trail ++ [ key ];

        holder = {
          inherit name;
          inherit (held) kind;
        };

        # the key is the origin string. two walked values are never compared
        # to each other, and only one node is forced at a time
        kept = gathered // {
          held = gathered.held // {
            ${key} = {
              inherit name value;
              inherit (held) kind;
            };
          };
        };
      in
      fx.pipe (fx.pure kept) (map (child: carried: descend deeper carried holder child) held.includes);

  # the edge is recorded before the value is absorbed, so a declaration two
  # hosts include is written under both and still walked once
  descend =
    trail: gathered: holder: value:
    Included.case {
      foreign =
        _:
        fx.bind (emit.foreign-include {
          at = [ holder.name ];
          context = {
            entry = holder.name;
          };
        }) (_: fx.pure gathered);

      anonymous =
        _:
        fx.bind (emit.unnameable-include {
          at = [ holder.name ];
          context = {
            entry = holder.name;
          };
        }) (_: fx.pure gathered);

      named =
        child:
        let
          held = construct.read child;
          name = nameOf held.origin;

          reached = carried: absorb trail carried held.origin name child;
        in
        Edge.case {
          beside = _: reached gathered;

          within =
            edge:
            reached (
              gathered
              // {
                links = gathered.links ++ [
                  {
                    inherit (edge) name into;
                  }
                ];
              }
            );

          misplaced =
            wrong:
            fx.bind (misplacement holder wrong) (
              _: reached (gathered // { refused = gathered.refused ++ [ name ]; })
            );
        } (edgeOf holder name held);
    } (classify value);

  plant =
    gathered: name: value:
    Seeded.case {
      opaque =
        _:
        fx.pure (
          gathered
          // {
            held = gathered.held // {
              ${name} = {
                inherit name value;
                kind = null;
              };
            };
          }
        );

      rooted = held: absorb [ ] gathered (keyFor name held) name held;
    } (seedOf value);

  # an include nobody could follow was named at the edge, so a value that
  # was refused there is not named again here
  residenceOf =
    gathered: entry:
    let
      described = if entry.kind == null then null else kindNamed entry.kind;

      linked = builtins.filter (link: link.name == entry.name) gathered.links;
    in
    if described == null then
      Residence.inject.unrecognised entry
    else if parentOf described == null then
      Residence.inject.rooted {
        inherit (described) collection;
        inherit (entry) name;
      }
    else if linked != [ ] || builtins.elem entry.name gathered.refused then
      Residence.inject.nested { paths = map (link: link.into ++ [ entry.name ]) linked; }
    else
      Residence.inject.unplaced (entry // { inherit (described) parent; });

  # a kind nobody registered, and a seed that is no construction, are both
  # named by the fold, so neither is decided here
  pathsOf =
    gathered: entry:
    Residence.case {
      rooted =
        at:
        fx.pure [
          [
            at.collection
            at.name
          ]
        ];

      nested = at: fx.pure at.paths;

      unplaced = at: fx.bind (homeless at) (_: fx.pure [ ]);

      unrecognised = _: fx.pure [ ];
    } (residenceOf gathered entry);

  # the key a value was gathered under is the file it came from, or the name
  # it was written under when it came from no file, which is the one segment
  # a diagnostic about a whole declaration is placed at
  placements =
    gathered:
    fx.map lib.listToAttrs (
      traverse (entry: fx.map (lib.nameValuePair entry.name) (pathsOf gathered entry)) (
        lib.mapAttrsToList (key: entry: entry // { place = [ key ]; }) gathered.held
      )
    );

  seeds =
    gathered:
    lib.listToAttrs (
      lib.mapAttrsToList (_: entry: lib.nameValuePair entry.name entry.value) gathered.held
    );

  gather =
    given:
    fx.bind
      (fx.pipe (fx.pure gathering) (
        lib.mapAttrsToList (
          name: value: carried:
          plant carried name value
        ) given
      ))
      (
        gathered:
        fx.map (placed: {
          values = seeds gathered;
          placements = placed;
        }) (placements gathered)
      );

  # anything that is not a set of seeds is handed on untouched, so the fold
  # keeps reporting that case where it always has
  flatten =
    given:
    Input.case {
      plain =
        value:
        fx.pure {
          values = value;
          placements = { };
        };
      set = gather;
    } (inputOf given);
in
{
  inherit flatten;
}
