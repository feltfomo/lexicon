{ program }:
program {
  files = [
    {
      # program supplies namespace, authority, managed root, and source shape to Furnish
      dest = ".config/paperkite/settings.conf";
      src = ./sources/settings.conf;
    }
  ];
}
