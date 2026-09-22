# a fleet of four machines built on lexicon
#
# what it proves, run from the root of the tree this flake sits in
#   nix eval --no-write-lock-file "path:$PWD?dir=mock#proof" --raw
#
# what it holds
#   nix eval --no-write-lock-file "path:$PWD?dir=mock#print" --raw
{
  description = "a nixos fleet built on lexicon";

  inputs = {
    # relative, so no reader's own paths reach this tree. a relative input
    # cannot leave the store copy of the flake it sits in, so it resolves
    # only while this flake is read through the dir query in the header
    lexicon.url = "path:..";

    # both are lexicon's own, so there is one of each in the evaluation
    nixpkgs.follows = "lexicon/nixpkgs";
    nix-effects.follows = "lexicon/nix-effects";
  };

  outputs =
    {
      lexicon,
      nixpkgs,
      nix-effects,
      ...
    }:
    let
      # the tree's own files import the library out of the tree they sit in, so
      # the fleet comes off the input's own copy of that tree
      mock = import (lexicon + "/mock/_boilerplate/proof.nix") {
        inherit (nixpkgs) lib;
        fx = nix-effects.lib;
        nixpkgs = nixpkgs.outPath;
      };
    in
    {
      inherit (mock) proof print;
    };
}
