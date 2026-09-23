# a dev shell declares the names it wants on its path, not the packages
# themselves. a package value belongs to a set telos is handed later, so the
# declaration holds names, which are plain data, and the shell is built in the
# dependent half
{ lib, fx, ... }:
let
  declaredOf = value: if builtins.isAttrs value then value else { };

  namesOf = declared: if builtins.isList (declared.packages or null) then declared.packages else [ ];

  named = value: builtins.isString value && value != "";
in
{
  name = "devShells";

  kinds = [
    "host"
    "fleet"
  ];

  before = [ ];

  claimable = [ ];

  codes = {
    devshells-interior = {
      message = "a devShells block must be an attrset of declared shells";
      help = "write the block as an attrset keyed by the name each shell takes in the flake";
    };

    devshells-packages-malformed = {
      message = args: "the shell ${args.rendered.shell or "?"} must declare packages as a list of names";
      help = "name the packages as strings; the package set they are read from arrives later";
    };

    # whether a name is in the set cannot be answered here, because the set
    # is handed to the assembly and not to a declaration
    devshells-package-unnamed = {
      message = args: "a package of the shell ${args.rendered.shell or "?"} is not a name";
      help = "write each package as a non-empty string";
    };
  };

  validate =
    { emit, value }:
    if !builtins.isAttrs value then
      emit.devshells-interior { }
    else
      fx.seq (
        lib.concatMap (
          name:
          let
            declared = declaredOf value.${name};
            packages = declared.packages or null;
          in
          lib.optional (!builtins.isList packages) (
            emit.devshells-packages-malformed {
              at = [ name ];
              context.shell = name;
            }
          )
          ++ lib.optional (builtins.isList packages && !builtins.all named packages) (
            emit.devshells-package-unnamed {
              at = [ name ];
              context.shell = name;
            }
          )
        ) (builtins.attrNames value)
      );

  compile = {
    independent =
      value: lib.mapAttrs (_: declared: { packages = namesOf (declaredOf declared); }) value;

    # the package set arrives in the context, so this is where a name becomes
    # a package and a shell becomes something nix develop can enter
    dependent =
      ctx: compiled:
      lib.mapAttrs (
        _: described:
        ctx.pkgs.mkShell {
          packages = map (
            name:
            ctx.pkgs.${name} or (throw "lexicon: the package ${name} is not in the package set handed to telos")
          ) described.packages;
        }
      ) compiled;
  };
}
