# a Home Manager module for the same package; import it from your Home Manager
# configuration, which must pass the flake inputs through
# extraSpecialArgs = { inherit inputs; }
{
  inputs,
  pkgs,
  ...
}:
{
  home.packages = [ inputs.lexicon.packages.${pkgs.system}.praxis ];
}
