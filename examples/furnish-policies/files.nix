{ lexicon }:
{
  imports = [ (lexicon.lib.furnishRuntime { }) ];

  lexicon.furnish = {
    enable = true;
    # raw declarations repeat stable identity, authority, and traversal boundaries
    declarations = [
      # immutable settings use a store-backed symlink and default conflict refusal
      {
        label = "paperkite settings";
        filesystemNamespace = "x86_64-linux/studio";
        authority = {
          scope = "user";
          identity = "river";
        };
        managedRoot = "/home/river";
        destination = ".config/paperkite/settings.conf";
        representation = "symlink";
        source = {
          kind = "path";
          value = ./sources/settings.conf;
        };
        provenance.source = "examples/furnish-policies/files.nix";
      }
      # notes stay writable and preserve runtime edits on two-sided divergence
      {
        label = "paperkite notes";
        filesystemNamespace = "x86_64-linux/studio";
        authority = {
          scope = "user";
          identity = "river";
        };
        managedRoot = "/home/river";
        destination = ".local/share/paperkite/notes.txt";
        representation = "writable";
        onConflict = "runtime-wins";
        source = {
          kind = "path";
          value = ./sources/notes.txt;
        };
        provenance.source = "examples/furnish-policies/files.nix";
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
        destination = ".cache/paperkite/generated.conf";
        representation = "writable";
        onConflict = "source-wins";
        source = {
          kind = "path";
          value = ./sources/generated.conf;
        };
        provenance.source = "examples/furnish-policies/files.nix";
      }
    ];
  };
}
