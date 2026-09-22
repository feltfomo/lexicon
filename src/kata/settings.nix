# the filename this subsystem answers to and the keys it takes, written as
# data the layer above reads. the walk gets its roots and its exclusions from
# whatever comes back
{ t }:
{
  name = "kata";
  filename = "kata.nix";

  schema = {
    roots = {
      type = t.listOf t.String;
      default = [ "modules" ];
    };

    # a path relative to a walk root, naming a file or a directory. renaming a
    # file must not change whether it loads, so nothing here is a spelling
    # rule over the tree
    exclude = {
      type = t.listOf t.String;
      default = [ ];
    };
  };
}
