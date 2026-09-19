let
  source = import ../tests/documentation-source.nix;
  lexicon = builtins.getFlake (builtins.unsafeDiscardStringContext (toString source));
in
import ./ownerships-suite.nix {
  inherit lexicon;
  inherit (lexicon.inputs) nixpkgs;
}
