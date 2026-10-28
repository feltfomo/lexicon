# one static inventory serves two principals, one materialization serves
# repeated demand, and furnish names the stage a callback failed in
let
  failsAt = context: {
    fails = true;
    context = [ context ];
  };
in
{
  prefix = "resource-effects";
  cells = {
    inventory.counts.inventory = 1;
    materialization.counts.materialize = 1;
    "exceptions.provider" = failsAt "furnish: while selecting applicable declarations";
    "exceptions.materializer" =
      failsAt "furnish: while materializing declaration 'resource' with executor 'test/selected'";
  };
}
