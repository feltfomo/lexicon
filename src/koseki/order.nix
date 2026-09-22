# every kind description, core or contributed, comes through here, so the
# defaults, the field ordering, the stamp check, the dependency check and
# the accessor collision check happen in one place and a later pass
# inherits all of them by calling the same function
{
  lib,
  types,
  field,
  accessors,
}:
let
  # a contributed kind may be written as plain data. filling the optional
  # parts once here keeps every later pass free of fallbacks on a kind
  prepare =
    kind:
    {
      parent = null;
      container = null;
      requirements = [ ];
      fields = [ ];
      collection = "${kind.name}s";
    }
    // kind
    // {
      fields = map field.describe (kind.fields or [ ]);
    };

  # core fields keep their declared order. contributed fields follow by the
  # position of the contribution, then by that contribution's own field
  # list order, then by field name, so the result never depends on the
  # order an attrset happened to iterate in
  contributedOrder =
    specs:
    lib.sort (
      a: b:
      if (a.index or 0) != (b.index or 0) then
        (a.index or 0) < (b.index or 0)
      else if (a.order or 0) != (b.order or 0) then
        (a.order or 0) < (b.order or 0)
      else
        a.name < b.name
    ) specs;

  # a contributed spec carries the position of the contribution that wrote
  # it, and a spec the kind declared itself carries none
  writerOf =
    kind: spec: if spec ? index then "contributions[${toString spec.index}]" else "kind ${kind.name}";

  # a second spec on one name takes the first one's place in silence, so
  # every later one is reported against the first that claimed the name
  collisionsOn =
    kind: fields:
    let
      writers = map (spec: {
        inherit (spec) name;
        writer = writerOf kind spec;
      }) fields;
    in
    lib.concatLists (
      lib.imap0 (
        position: held:
        let
          earlier = builtins.filter (one: one.name == held.name) (lib.take position writers);
        in
        lib.optional (earlier != [ ]) {
          code = "field-collision";
          args = {
            at = [
              kind.name
              held.name
            ];
            context = {
              field = held.name;
              first = (builtins.head earlier).writer;
              second = held.writer;
            };
          };
        }
      ) writers
    );

  stampProblems =
    kind: fields:
    lib.concatMap (
      description:
      lib.optional (!types.blessed description.type) {
        code = "foreign-type";
        args = {
          at = [
            kind.name
            description.name
          ];
          context = {
            field = description.name;
            kind = kind.name;
          };
        };
      }
    ) fields;

  # a field may only depend on a field ordered before it, wherever either
  # field came from. a derivation may read any field on self, and dependsOn
  # constrains ordering only
  dependencyProblems =
    kind: fields:
    let
      names = map (description: description.name) fields;
      indexOf = name: lib.lists.findFirstIndex (candidate: candidate == name) null names;
    in
    lib.concatLists (
      lib.imap0 (
        position: description:
        lib.concatMap (
          dependency:
          let
            found = indexOf dependency;
          in
          lib.optional (found == null || found >= position) {
            code = "dependency-order";
            args = {
              at = [
                kind.name
                description.name
              ];
              context = {
                field = description.name;
                inherit dependency;
              };
            };
          }
        ) (description.dependsOn or [ ])
      ) fields
    );

  # the pair is fully determined by the resolved kind list, so the report
  # belongs beside the other schema-level problems and never at the door
  collisionProblems =
    kinds:
    map (collision: {
      code = "accessor-collision";
      args = {
        at = [
          "accessors"
          collision.first.name
        ];
        context = {
          accessor = collision.first.name;
          first = collision.first.subject;
          second = collision.second.subject;
        };
      };
    }) (accessors.collisions kinds);

  resolveKinds =
    {
      kinds,
      fields ? { },
      requirements ? { },
    }:
    let
      resolve =
        kind:
        let
          contributed = contributedOrder (fields.${kind.name} or [ ]);

          ordered = kind.fields ++ map field.describe contributed;
        in
        {
          resolved = kind // {
            fields = ordered;
            fieldNames = map (description: description.name) ordered;
            requirements = kind.requirements ++ (requirements.${kind.name} or [ ]);
          };
          problems =
            stampProblems kind ordered
            ++ dependencyProblems kind ordered
            # the description drops the position a spec came from, so the
            # writers are read off the specs as they arrived
            ++ collisionsOn kind (kind.fields ++ contributed);
        };

      resolved = map resolve (map prepare kinds);
      settled = map (entry: entry.resolved) resolved;
    in
    {
      kinds = settled;
      problems = lib.concatMap (entry: entry.problems) resolved ++ collisionProblems settled;
    };
in
{
  inherit resolveKinds;
}
