{ entry, lexicon, ... }:
entry {
  includes = with lexicon; [ a ];
  nixos = { };
}
