{ entry, lexicon, ... }:
entry {
  includes = with lexicon; [
    editor
    desktop
  ];
  nixos = { };
}
