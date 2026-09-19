{ program }:
program {
  # a claim names which roster principals receive this declaration
  users = [ "river" ];
  files = [
    {
      dest = ".config/paperkite/den.conf";
      src = ./settings.conf;
    }
  ];
}
