{ program }:
program {
  directories = [
    {
      src = ./sources/snippets;
      dest = ".config/paperkite/snippets";
      exclude = [ "draft.conf" ];
      files = [
        {
          names = [ "notes.conf" ];
          # runtime edits are intentional for the writable notes file
          representation = "writable";
          onConflict = "runtime-wins";
          provenance = "examples/program-files/directory.nix";
        }
      ];
    }
  ];
}
