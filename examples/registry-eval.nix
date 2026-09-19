let
  source = import ../tests/documentation-source.nix;
  lexicon = builtins.getFlake (builtins.unsafeDiscardStringContext (toString source));
in
import ./registry-suite.nix { inherit lexicon; }
