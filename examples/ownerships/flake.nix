{
  description = "Select preferences for two users and two machines";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.lexicon.url = "github:feltfomo/lexicon";

  outputs = { nixpkgs, lexicon, ... }: {
    # the locked nixpkgs library keeps results independent of evaluator defaults
    lib = import ./preferences.nix {
      inherit lexicon;
      inherit (nixpkgs) lib;
    };
  };
}
