{ program }:
program {
  # imports carry ordinary Home Manager module content through untouched
  imports = [ { home.sessionVariables.EDITOR = "hx"; } ];
}
