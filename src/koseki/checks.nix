# the checks that ship with the subsystem. each one is built from its own
# configuration and nothing else, and every finding names the entities it
# is talking about
{ lib }:
let
  entitiesOf = registry: kind: builtins.filter (entity: entity.kind == kind) registry.entities;

  # an absent field is not this check's business. the type pass already has
  # an opinion about a field that had to be there
  carries = field: entity: entity.value ? ${field} && entity.value.${field} != null;

  pathOf = field: entity: entity.sourcePath ++ [ field ];

  uniqueAcross =
    {
      kind,
      field,
      name ? "unique-${field}-across-${kind}",
    }:
    {
      inherit name;
      run =
        registry:
        let
          present = builtins.filter (carries field) (entitiesOf registry kind);
          sharing = value: builtins.filter (entity: entity.value.${field} == value) present;
          values = lib.unique (map (entity: entity.value.${field}) present);
          duplicated = builtins.filter (value: builtins.length (sharing value) > 1) values;
        in
        map (
          value:
          let
            group = sharing value;
          in
          {
            detail = "more than one ${kind} declares the same ${field}";
            entities = map (entity: entity.key) group;
            at = pathOf field (builtins.head group);
            paths = map (pathOf field) (builtins.tail group);
            context = {
              inherit value;
            };
          }
        ) duplicated;
    };

  # a flag exactly one entity of a kind is allowed to set. none and several
  # are both wrong, and both findings name the entities that were weighed
  exactlyOne =
    {
      kind,
      field,
      name ? "exactly-one-${kind}-sets-${field}",
    }:
    {
      inherit name;
      run =
        registry:
        let
          all = entitiesOf registry kind;
          chosen = builtins.filter (entity: (entity.value.${field} or false) == true) all;
        in
        if builtins.length chosen == 1 then
          [ ]
        else if chosen == [ ] then
          [
            {
              detail = "no ${kind} sets ${field}, and exactly one must";
              entities = map (entity: entity.key) all;
            }
          ]
        else
          [
            {
              detail = "more than one ${kind} sets ${field}, and exactly one must";
              entities = map (entity: entity.key) chosen;
              at = pathOf field (builtins.head chosen);
              paths = map (pathOf field) (builtins.tail chosen);
            }
          ];
    };

  # a field holding the key of another entity. a dangling reference is this
  # checks failure and not the core vocabulary's, so it reports as a check
  # rather than borrowing a code that means something narrower
  referenceExists =
    {
      kind,
      field,
      target,
      name ? "${field}-of-${kind}-names-a-${target}",
    }:
    {
      inherit name;
      run =
        registry:
        let
          known = map (entity: entity.key) (entitiesOf registry target);
          referring = builtins.filter (carries field) (entitiesOf registry kind);
          dangling = builtins.filter (
            entity: !builtins.elem (toString entity.value.${field}) known
          ) referring;
        in
        map (entity: {
          detail = "${field} names a ${target} that was never declared";
          entities = [ entity.key ];
          at = pathOf field entity;
          context = {
            reference = entity.value.${field};
          };
        }) dangling;
    };
in
{
  inherit
    uniqueAcross
    exactlyOne
    referenceExists
    ;
}
