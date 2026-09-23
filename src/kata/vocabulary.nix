# every code kata can report, declared once and up front. a problem the
# layer below already reports keeps that layer's code, so a caller never
# sees one problem twice under two names
#
# the codes the walk reports arrive as an argument and are read under this
# namespace, because the tree they are about is the one kata's settings file
# named
{ krisis, codes }:
let
  shown = args: name: args.rendered.${name} or "?";

  # a value the reporter built as prose is taken as written, and anything
  # else falls back to the rendered form
  prose =
    args: name:
    let
      value = (args.context or { }).${name} or null;
    in
    if builtins.isString value then value else shown args name;
in
krisis.vocabulary {
  namespace = "kata";

  codes = {
    unknown-kind = {
      message = args: "unknown kind ${shown args "kind"}";
      help = "a kind is one of the constructors kata exposes; build the value with one of them";
    };

    disallowed-block = {
      message = args: "kind ${shown args "kind"} may not carry the block ${shown args "block"}";
      help = "move the block to a kind that carries it, or drop it";
    };

    malformed-construction = {
      message = args: "${prose args "what"} must be ${prose args "expected"}";
    };

    # a walker may reach a declaration naming a block whose subsystem is not
    # registered yet, so this one is tolerated until the caller asks for strict
    unknown-block = {
      severity = "warning";
      message = args: "no block named ${shown args "block"} is registered";
      help = "register the block, or drop the key until its subsystem exists";
    };

    malformed-claim = {
      message = args: "the claim ${shown args "claim"} must be a list of names";
      help = "a claim names the hosts or users it applies to";
    };

    # the claim is well formed and names something the declaration does not
    # hold. it is placed at the file the claim was written in, because the
    # name it got in the declaration is not where anyone would go to fix it
    unknown-claimed-host = {
      message = args: "no host named ${shown args "host"} is declared";
      help = "claim a host the fleet declares, or declare the host";
    };

    unknown-claimed-user = {
      message = args: "no user named ${shown args "user"} is declared";
      help = "claim a user one of the declared hosts holds, or declare the user";
    };

    unwalkable-claim-route = {
      message =
        args: "block ${shown args "block"} declares a claimable route through a node built at use";
      help = "declare the route over the part of the interior that is plain data";
    };

    malformed-registration = {
      message =
        args:
        "block ${shown args "block"} registers ${prose args "field"}, which must be ${prose args "expected"}";
    };

    unknown-block-edge = {
      message =
        args: "block ${shown args "block"} orders itself before the unregistered ${shown args "edge"}";
    };

    block-cycle = {
      message = args: "the registered blocks order themselves in a cycle, ${shown args "cycle"}";
      help = "drop one of the edges named in the cycle";
    };

    include-cycle = {
      message = args: "the includes run in a cycle, ${prose args "cycle"}";
      help = "drop one of the includes named in the cycle";
    };

    foreign-include = {
      message = args: "${shown args "entry"} includes something that is not a declaration";
      help = "an include names another declaration; build it with one of kata's constructors";
    };

    # a value built inline has no origin, and a name is what places it
    unnameable-include = {
      message = args: "${shown args "entry"} includes a declaration that came from no file";
      help = "put the declaration in its own file under a walk root and include it by name";
    };

    # the kind registry says which kind an included value lands inside, and
    # both kinds are named so the fix is a choice between them
    misplaced-include = {
      message =
        args:
        "${prose args "entry"} includes the ${prose args "kind"} ${prose args "name"}, which belongs to a ${prose args "parent"}";
      help = "include it from the kind it belongs to, or build it as the kind this one may include";
    };

    unplaced-declaration = {
      message =
        args:
        "nothing includes the ${prose args "kind"} ${prose args "name"}, so it reaches no ${prose args "parent"}";
      help = "include it from the declaration it belongs to, or drop the file";
    };
  }
  // codes { inherit shown prose; };
}
// {
  # a block writes its own codes, and reading an argument the same way here
  # and there keeps one sentence from mixing two spellings of a value
  text = {
    inherit shown prose;
  };
}
