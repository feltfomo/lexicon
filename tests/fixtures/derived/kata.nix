{ library, root, ... }:
let
  kinds = map (kind: kind.name) library.kata.internal.kinds;
in
{
  roots = [ "modules" ];

  exclude = map (name: "scratch/${name}.nix") (kinds ++ [ (baseNameOf root) ]);
}
