{
  description = "One shared Lexicon registry";
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs =
    { lexicon, ... }:
    let
      registry = lexicon.lib.registry (import ./lexicon.nix);
    in
    {
      lib = {
        inherit registry;
        inherit (registry) summary;
        desk = registry.host "desk";
        home = registry.homeFor {
          host = "workstation";
          user = "operator";
        };
      };
    };
}
