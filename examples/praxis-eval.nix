let
  source = import ../tests/documentation-source.nix;
  checkout = builtins.getFlake "path:${builtins.unsafeDiscardStringContext (toString source)}";
in
import ./praxis-suite.nix {
  lexicon = checkout;
  nixpkgs = checkout.inputs.nixpkgs;
}
