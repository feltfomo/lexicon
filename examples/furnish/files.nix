{ lexicon }:
{
  # the bound runtime supplies pinned native executors
  imports = [ (lexicon.lib.furnishRuntime { }) ];

  lexicon.furnish = {
    enable = true;
    declarations = [
      # stable namespace, runtime authority, and traversal bounds are explicit in the raw interface
      {
        label = "paperkite settings";
        filesystemNamespace = "x86_64-linux/studio";
        authority = {
          scope = "user";
          identity = "river";
        };
        managedRoot = "/home/river";
        destination = ".config/paperkite/settings.conf";
        # immutable settings stay tied to the retained store artifact
        representation = "symlink";
        source = {
          kind = "path";
          value = ./settings.conf;
        };
      }
    ];
  };
}
