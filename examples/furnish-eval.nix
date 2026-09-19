let
  source = import ../tests/documentation-source.nix;
  lexicon = builtins.getFlake (builtins.unsafeDiscardStringContext (toString source));
in
import ./furnish-suite.nix {
  inherit lexicon;
  inherit (lexicon.inputs) nixpkgs;
}
