# every code this subsystem can report, declared once and up front. codes
# whose producers arrive in a later pass are registered here anyway, so the
# catalogue never changes meaning under a caller
{ krisis }:
let
  shown = args: name: args.rendered.${name} or "?";

  # a value that reads as prose in a message is taken as the string the
  # reporter built, and anything else falls back to the rendered form
  prose =
    args: name:
    let
      value = (args.context or { }).${name} or null;
    in
    if builtins.isString value then value else shown args name;
in
krisis.vocabulary {
  namespace = "lexicon";

  codes = {
    unknown-field = {
      message = args: "unknown field ${shown args "field"}";
      help = "remove the field, or check it against the fields this kind declares";
    };

    unknown-kind = {
      message = args: "unknown top-level key ${shown args "key"}";
    };

    missing-field = {
      message = args: "required field ${shown args "field"} is missing";
    };

    invalid-value = {
      message =
        args: "field ${shown args "field"} expected ${shown args "type"}, got ${shown args "value"}";
    };

    requirement-failed = {
      message = args: "requirement ${shown args "requirement"} failed";
    };

    check-failed = {
      message =
        args: "check ${shown args "check"} failed on ${prose args "entities"}, ${prose args "detail"}";
    };

    malformed-check = {
      message =
        args: "check ${shown args "check"} did not produce findings, it produced ${shown args "produced"}";
      help = "a check is an attrset of a name and a run, where run takes the registry and hands back a list of findings";
    };

    accessor-collision = {
      message =
        args:
        "accessor ${shown args "accessor"} is claimed by both ${shown args "first"} and ${shown args "second"}";
      help = "rename one of the two. the path names the accessor namespace in the schema, not a place in your declaration";
    };

    # both writers are named, because which of the two to rename is the
    # caller's choice and not the resolver's
    field-collision = {
      message =
        args:
        "field ${shown args "field"} is declared by both ${prose args "first"} and ${prose args "second"}";
      help = "rename the field, or drop the contribution that declares it a second time";
    };

    foreign-type = {
      message = args: "field ${shown args "field"} was declared with a type from another instance";
      help = "build the type with lexicon.t.*, which stamps it for this instance. the path names the kind and field in the schema, not a place in your declaration";
    };

    dependency-order = {
      message =
        args:
        "field ${shown args "field"} depends on ${shown args "dependency"}, which is not ordered before it";
      help = "the path names the kind and field in the schema, not a place in your declaration";
    };

    unknown-host = {
      message = args: "no host named ${shown args "name"}";
    };

    unknown-user = {
      message = args: "no user named ${shown args "name"}";
    };

    unmapped-blame = {
      message = "a type check failed in a way this version cannot attribute to a field";
      help = "the raw blame path is in the notes; please report it";
    };

    unimplemented-key = {
      message = args: "the key ${shown args "key"} is reserved and does nothing yet";
    };

    derived-override = {
      severity = "info";
      message = args: "field ${shown args "field"} is derived; the declared value takes precedence";
    };

    source-override = {
      severity = "info";
      message = args: "field ${shown args "field"} was overridden by ${shown args "source"}";
      help = "the path names the contribution that did not take effect";
    };

    rename-repairing = {
      severity = "info";
      message =
        args:
        "host ${shown args "host"} arrives as ${shown args "name"}, which changes the host it pairs with";
    };

    narrowing-collision = {
      message =
        args:
        "hosts under ${prose args "systems"} both narrow onto the name ${shown args "name"}, and the source calls them ${prose args "evidence"}";
      help = "rename one of the two through the source's renames";
    };

    unknown-rename = {
      message = args: "the rename ${shown args "rename"} names no host of source ${shown args "source"}";
    };

    rename-collision = {
      message =
        args:
        "the rename ${shown args "rename"} lands on ${shown args "name"}, which is already claimed by ${prose args "claimant"}";
    };

    source-name-collision = {
      message = args: "a second source is named ${shown args "name"}";
      help = "name one of them something else, the name keys what a source contributed";
    };
  };
}
