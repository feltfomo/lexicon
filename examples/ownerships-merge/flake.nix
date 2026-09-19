{
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs = { lexicon, ... }: {
    lib = import ./values.nix { inherit lexicon; };
  };
}
