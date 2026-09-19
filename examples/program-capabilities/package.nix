{ program }:
program {
  # pkg is lowered into the bound user's Home Manager package list
  pkg = pkgs: pkgs.hello;
}
