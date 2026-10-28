# callback counts of the compiler fixture across two contexts. static entries
# are prepared once and shared, entries a callback produces are prepared per
# context, and a failing callback names its authored demand site
let
  counts = perContext: {
    "parse 0" = 2;
    "parse 1" = 2;
    normalize = 4;
    metadata = 7;
    "preparation root" = 1;
    "preparation 0" = perContext;
    "preparation 1" = perContext;
    lowering = 2;
    callback = if perContext == 1 then 0 else 2;
  };
  failsAt = context: {
    fails = true;
    context = [ context ];
  };
in
{
  prefix = "compiler";
  cells = {
    static.counts = counts 1;
    dynamic.counts = counts 2;
    "exceptions.callback" = failsAt "lexicon callback at $.sample";
    "exceptions.preparation" = failsAt "lexicon preparation at $.sample";
    "exceptions.lowering" = failsAt "lexicon lowering block sample";
  };
}
