# every code telos reports from outside a block. a code a block owns is
# declared on that block, so one mistake reaches a person under one name
#
# the codes the walk reports arrive as an argument and are read under this
# namespace, because the tree they are about is the one telos's settings file
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
  namespace = "telos";

  codes = {
    # prefixing the host onto the attribute would make the path unguessable
    # from the file the person wrote, so both declarations are named and
    # neither one quietly wins
    output-name-collision = {
      message =
        args:
        "${shown args "output"} is declared for ${shown args "system"} more than once, by ${prose args "sources"}";
      help = "rename one of them, or declare it once for the fleet instead of once per host";
    };

    # an attribute holding one value has no name level to tell two well formed
    # declarations apart, so they are refused where they meet rather than in
    # either declaration, and both are dropped because neither has the better
    # claim on the attribute
    contended-output-attribute = {
      message =
        args:
        "${shown args "block"} may declare one output for ${shown args "system"}, and ${prose args "outputs"} were declared by ${prose args "sources"}";
      help = "declare one of them, or drop the rest";
    };

    # two files declaring one output name for one host reduce to one
    # attribute when their declarations are merged, so the doubling is
    # refused where both files are still in hand
    doubled-output-declaration = {
      message =
        args:
        "${shown args "output"} is declared for ${prose args "declared"} by more than one file, ${prose args "files"}";
      help = "declare it in one of the files, or rename one of them";
    };

    malformed-declaration = {
      message = args: "${prose args "what"} must be ${prose args "expected"}";
    };

    unknown-output-block = {
      message = args: "no output block named ${shown args "block"} is registered";
      help = "register the block, or drop the key";
    };

    # a kind carries the blocks the blocks themselves say they reach, so this
    # names the pair rather than either half
    disallowed-output-block = {
      message = args: "${shown args "kind"} may not declare the output block ${shown args "block"}";
      help = "declare it where that block is carried, or drop it";
    };

    unknown-declaring-host = {
      message = args: "no host named ${shown args "host"} is declared";
      help = "declare outputs for a host the fleet holds, or move them to the fleet";
    };

    # the package set cannot be reached from inside telos, so its absence is
    # a missing capability and not a missing import
    missing-package-set = {
      message = args: "no package set was handed in for ${shown args "system"}";
      help = "hand telos a package set for every system a host declares";
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
