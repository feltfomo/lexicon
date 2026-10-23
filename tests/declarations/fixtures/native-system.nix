{ lib, ... }:
{
  options.nativeResult = lib.mkOption {
    type = lib.types.attrs;
    default = { };
  };
  config.nativeResult.path = true;
}
