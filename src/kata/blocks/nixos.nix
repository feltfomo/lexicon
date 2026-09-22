# the interior belongs to the module system, so the only thing read here is
# whether it is a shape that system takes. it carries no claimable route
# because a module is routinely a function and there is nothing to walk until
# its arguments exist
{ fx, ... }:
let
  isModule = value: builtins.isAttrs value || builtins.isFunction value;
in
{
  name = "nixos";

  kinds = [ "entry" ];

  before = [ ];

  claimable = [ ];

  codes = {
    nixos-interior = {
      message = "a nixos block must be a module, a function of one, or a list of either";
      help = "write the block as an attrset, a function of the module arguments, or a list of those";
    };
  };

  validate =
    { emit, value }:
    if isModule value || (builtins.isList value && builtins.all isModule value) then
      fx.pure null
    else
      emit.nixos-interior { };

  compile = {
    independent = value: {
      modules = if builtins.isList value then value else [ value ];
    };
    dependent = _: compiled: compiled;
  };
}
