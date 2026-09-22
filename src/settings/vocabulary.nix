# every code this layer can report. a problem inside a subsystem's own slice
# keeps that subsystem's codes, so a caller never sees one problem twice under
# two names
{ krisis }:
let
  shown = args: name: args.rendered.${name} or "?";
in
krisis.vocabulary {
  namespace = "settings";

  codes = {
    unknown-key = {
      message =
        args:
        "${shown args "file"} sets ${shown args "key"}, which ${shown args "subsystem"} does not take";
      help = "drop the key, or check it against the keys the subsystem declares";
    };

    malformed-file = {
      message = args: "${shown args "file"} must hand back an attrset of settings";
      help = "a settings file takes library and root and hands back an attrset";
    };

    malformed-value = {
      message =
        args:
        "${shown args "file"} sets ${shown args "key"} to something that must be ${shown args "expected"}";
    };

    # a registration is registry data rather than a caller's writing, and it
    # is read on the same stream so nobody has to look elsewhere for it
    malformed-registration = {
      message =
        args: "a subsystem registers ${shown args "field"}, which must be ${shown args "expected"}";
      help = "a registration carries a name, the filename it answers to, and its schema";
    };
  };
}
