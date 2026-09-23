# the filename this subsystem answers to and the keys it takes, written as
# data the layer above reads. the walk is shared, so both keys it reads off
# a slice are declared here
{ t }:
{
  name = "telos";
  filename = "telos.nix";

  schema = {
    # nothing is walked for outputs until a tree is named, so a configuration
    # that writes no telos.nix walks the same trees it always did
    roots = {
      type = t.listOf t.String;
      default = [ ];
    };

    # a path relative to a walk root. it is matched whole against a file or as
    # a directory prefix, never as a pattern, and one that covers nothing
    # under the roots named above is reported rather than ignored
    exclude = {
      type = t.listOf t.String;
      default = [ ];
    };
  };
}
