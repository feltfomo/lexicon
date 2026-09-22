{ entry, lexicon, ... }:
entry {
  includes = with lexicon; [ b ];
  nixos = { };
}
