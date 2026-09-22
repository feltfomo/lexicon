# the queryable namespace is built in named layers with a fixed precedence.
# the collision check and the namespace build both read the layer list here
{ lib }:
let
  # highest first. a higher layer wins silently, and the order the kinds
  # were resolved in decides nothing
  layers = [
    "collection"
    "lookup"
    "child"
    "field"
  ];

  # one accessor per field name, from the union across every resolved kind
  fieldNames =
    kinds: lib.unique (lib.concatMap (kind: map (description: description.name) kind.fields) kinds);

  # a registrant is a kind's place in the resolved list, and the field layer
  # registers as -1 because the union already collapsed the names it owns
  claimsOf =
    kinds:
    let
      indexed = lib.imap0 (registrant: kind: { inherit registrant kind; }) kinds;

      claim = layer: name: subject: registrant: {
        inherit
          layer
          name
          subject
          registrant
          ;
      };
    in
    map (
      entry:
      claim "collection" entry.kind.collection "the collection of kind ${entry.kind.name}"
        entry.registrant
    ) indexed
    ++ map (
      entry: claim "lookup" entry.kind.name "the lookup for kind ${entry.kind.name}" entry.registrant
    ) indexed
    ++ map (
      entry:
      claim "child" "${entry.kind.collection}Of" "the child accessor of kind ${entry.kind.name}"
        entry.registrant
    ) (builtins.filter (entry: entry.kind.parent != null) indexed)
    ++ map (name: claim "field" "${name}Of" "the field accessor for ${name}" (-1)) (fieldNames kinds);

  # two claims on one name are legitimate only where a child accessor sits
  # over a field accessor
  legitimate =
    first: second:
    let
      pair = [
        first.layer
        second.layer
      ];
    in
    pair == [
      "child"
      "field"
    ]
    ||
      pair == [
        "field"
        "child"
      ];

  # every other pair on one name is a collision, including two layers of one
  # kind, where the lower layer loses its accessor
  collisions =
    kinds:
    let
      claims = claimsOf kinds;
      names = lib.unique (map (claim: claim.name) claims);
      groupFor = name: builtins.filter (claim: claim.name == name) claims;

      pairsIn =
        group:
        lib.concatLists (
          lib.imap0 (
            position: first: map (second: { inherit first second; }) (lib.drop (position + 1) group)
          ) group
        );

      offending = pair: !legitimate pair.first pair.second;
    in
    lib.concatMap (name: builtins.filter offending (pairsIn (groupFor name))) names;

  # lowest layer first, so each merge is a higher layer landing on a lower
  merge =
    byLayer:
    lib.foldl' (accumulated: layer: accumulated // (byLayer.${layer} or { })) { } (
      lib.reverseList layers
    );
in
{
  inherit
    layers
    fieldNames
    collisions
    merge
    ;
}
