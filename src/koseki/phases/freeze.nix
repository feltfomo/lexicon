# phase four puts the registry in a let binding and hands back only the
# accessors, so unreachability is structural rather than a convention
{ query }:
let
  run =
    {
      kinds,
      provenance,
      registry,
    }:
    query.make {
      inherit kinds provenance;
      inherit (registry) entities;
    };
in
{
  inherit run;
}
