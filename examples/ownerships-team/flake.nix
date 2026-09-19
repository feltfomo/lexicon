{
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs = { lexicon, ... }: {
    lib = import ./team.nix { inherit lexicon; };
  };
}
