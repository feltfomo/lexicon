{ lexicon }:
let
  config = import ./registry-minimal/lexicon.nix;
  result = (lexicon.lib.registry config).summary;
  changed =
    (lexicon.lib.registry (
      config
      // {
        hosts = config.hosts // {
          vault.dimensions.role = "server";
        };
      }
    )).summary;
in
{
  minimal = {
    inherit result changed;
  };
}
