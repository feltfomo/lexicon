# the formatter a tree runs. it declares the program that formats, not which
# tool reads which file, because the file a tool is right for is a fact about
# the program and not about the tree that runs it
#
# the attribute it lands under holds one value rather than a set of names, so
# a tree declaring two formatters is refused where the two meet rather than
# here, where each one on its own is well formed
#
# TODO the program is named against the package set a configuration is handed,
# so a formatter that set does not carry cannot be named at all. a declared
# tool table, and a way to name a program that arrives with lexicon rather
# than with the package set, land here when the declaration surface grows one
{ lib, fx, ... }:
let
  declaredOf = value: if builtins.isAttrs value then value else { };

  programOf = declared: declared.program or null;

  named = value: builtins.isString value && value != "";
in
{
  name = "fmt";

  kinds = [
    "host"
    "fleet"
  ];

  before = [ ];

  claimable = [ ];

  codes = {
    fmt-interior = {
      message = "an fmt block must be an attrset of declared formatters";
      help = "write the block as an attrset keyed by the name the formatter takes";
    };

    # whether the name is in the set cannot be answered here, because the set
    # is handed to the assembly and not to a declaration
    fmt-program-unnamed = {
      message = args: "the formatter ${args.rendered.formatter or "?"} must name the program it runs";
      help = "write the program as a non-empty string; the package set it is read from arrives later";
    };
  };

  validate =
    { emit, value }:
    if !builtins.isAttrs value then
      emit.fmt-interior { }
    else
      fx.seq (
        lib.concatMap (
          name:
          lib.optional (!named (programOf (declaredOf value.${name}))) (
            emit.fmt-program-unnamed {
              at = [ name ];
              context.formatter = name;
            }
          )
        ) (builtins.attrNames value)
      );

  compile = {
    independent =
      value: lib.mapAttrs (_: declared: { program = programOf (declaredOf declared); }) value;

    # the package set arrives in the context, so this is where a name becomes
    # the program nix fmt runs
    dependent =
      ctx: compiled:
      lib.mapAttrs (
        _: described:
        ctx.pkgs.${described.program}
          or (throw "lexicon: the program ${described.program} is not in the package set handed to telos")
      ) compiled;
  };
}
