{ entry, lexicon, ... }:
entry {
  includes = with lexicon; [ editor ];
  nixos = { };
}
