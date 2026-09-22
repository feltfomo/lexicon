# every code emission can report, declared once and up front. a problem the
# declaration layer already reports keeps that layer's code
{ krisis, text }:
let
  inherit (text) shown prose;
in
krisis.vocabulary {
  namespace = "emit";

  codes = {
    missing-capability = {
      message = args: "backend ${shown args "backend"} needs the capability ${shown args "capability"}";
      help = "hand the capability to the door, or leave the backend out of the run";
    };

    malformed-capability = {
      message = args: "the capability ${shown args "capability"} must be a function";
      help = "a capability is applied by the backend that needs it";
    };

    # the module system looks up every name a wrapper advertises before
    # anything is evaluated
    unsupplyable-context-argument = {
      message =
        args:
        "backend ${shown args "backend"} names the module argument ${shown args "argument"}, which nothing supplies";
      help = "name an argument the evaluator injects, or bind it in the backend";
    };

    aspect-carries-includes = {
      message = args: "the declaration used as an aspect carries ${shown args "includes"} includes";
      help = "the aspect system follows its own includes; hand this one a declaration that has none";
    };

    aspect-carries-claim = {
      message =
        args:
        "the declaration used as an aspect claims ${shown args "claim"} on block ${shown args "block"}";
      help = "drop the claim; the system that reads the aspect places it";
    };

    # a value crossing into emission that is not the shape emission reads.
    # the door, a claim and a target each have a type, and this is what a
    # failure of one says
    malformed-emission = {
      message = args: "${prose args "what"} must be ${prose args "expected"}";
    };
  };
}
