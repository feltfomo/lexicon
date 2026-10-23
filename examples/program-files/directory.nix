{ lexicon }:
lexicon {
  furnish.directories = [
    {
      source = ./sources/snippets;
      destination = ".config/paperkite/snippets";
      exclude = [ "draft.conf" ];
      files = [
        {
          names = [ "notes.conf" ];
          representation = "writable";
          onConflict = "runtime-wins";
          provenance = "examples/program-files/directory.nix";
        }
      ];
    }
  ];
}
