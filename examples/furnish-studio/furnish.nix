{
  lexicon.furnish = {
    enable = true;
    # every entry repeats the stable host namespace and its traversal boundary
    declarations = [
      # immutable editor settings stay tied to the retained store artifact
      {
        label = "paperkite editor settings";
        filesystemNamespace = "x86_64-linux/studio";
        authority = {
          scope = "user";
          identity = "river";
        };
        managedRoot = "/home/river";
        destination = ".config/paperkite/editor.conf";
        representation = "symlink";
        source = {
          kind = "path";
          value = ./sources/editor.conf;
        };
        provenance.source = "examples/furnish-studio/furnish.nix";
      }
      {
        label = "paperkite shortcuts";
        filesystemNamespace = "x86_64-linux/studio";
        authority = {
          scope = "user";
          identity = "river";
        };
        managedRoot = "/home/river";
        destination = ".config/paperkite/shortcuts.conf";
        representation = "symlink";
        source = {
          kind = "path";
          value = ./sources/shortcuts.conf;
        };
        provenance.source = "examples/furnish-studio/furnish.nix";
      }
      # drafts stay writable and preserve runtime edits on two-sided divergence
      {
        label = "paperkite drafts";
        filesystemNamespace = "x86_64-linux/studio";
        authority = {
          scope = "user";
          identity = "river";
        };
        managedRoot = "/home/river";
        destination = ".local/share/paperkite/drafts.txt";
        representation = "writable";
        onConflict = "runtime-wins";
        source = {
          kind = "path";
          value = ./sources/drafts.txt;
        };
        provenance.source = "examples/furnish-studio/furnish.nix";
      }
      # generated data stays writable but declared source wins two-sided divergence
      {
        label = "paperkite generated index";
        filesystemNamespace = "x86_64-linux/studio";
        authority = {
          scope = "user";
          identity = "river";
        };
        managedRoot = "/home/river";
        destination = ".cache/paperkite/generated-index.conf";
        representation = "writable";
        onConflict = "source-wins";
        source = {
          kind = "path";
          value = ./sources/generated-index.conf;
        };
        provenance.source = "examples/furnish-studio/furnish.nix";
      }
      # system authority manages the etc tree without using river's account
      {
        label = "paperkite system service";
        filesystemNamespace = "x86_64-linux/studio";
        authority = {
          scope = "system";
          identity = "x86_64-linux/studio";
        };
        managedRoot = "/etc";
        destination = "paperkite/service.conf";
        representation = "symlink";
        source = {
          kind = "path";
          value = ./sources/service.conf;
        };
        provenance.source = "examples/furnish-studio/furnish.nix";
      }
    ];
  };
}
