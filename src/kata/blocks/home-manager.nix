# same interior shape as the system block and the same reason for carrying no
# claimable route. it is legal in the home-directory kind as well, which is the
# only thing that separates the two registrations
{ fx, ... }:
let
  isModule = value: builtins.isAttrs value || builtins.isFunction value;
in
{
  name = "homeManager";

  kinds = [
    "entry"
    "home"
  ];

  before = [ ];

  claimable = [ ];

  codes = {
    home-manager-interior = {
      message = "a homeManager block must be a module, a function of one, or a list of either";
      help = "write the block as an attrset, a function of the module arguments, or a list of those";
    };
  };

  validate =
    { emit, value }:
    if isModule value || (builtins.isList value && builtins.all isModule value) then
      fx.pure null
    else
      emit.home-manager-interior { };

  compile = {
    independent = value: {
      modules = if builtins.isList value then value else [ value ];
    };
    dependent = _: compiled: compiled;
  };
}
