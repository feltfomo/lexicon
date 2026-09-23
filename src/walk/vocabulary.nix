# the codes a walk reports, declared once and read under the namespace of
# the subsystem whose settings file named the tree. a subsystem spreads
# these into its own vocabulary, so one mistake reaches a person in the
# words of the layer that owns the file it was written in
{
  codes =
    { shown, prose }:
    {
      unknown-walk-root = {
        message = args: "there is no ${shown args "root"} under the configuration root";
        help = "create the directory, or name the tree that holds the declarations";
      };

      excluded-path-missing = {
        message = args: "nothing under any walk root is at ${shown args "path"}";
        help = "drop the exclusion, or write it as a path relative to the root that holds it";
      };

      # two files landing on one name is read off the file list before anything
      # is imported, so both files are named and neither quietly wins. the names
      # are origins, which carry the root each file was offered from
      entry-name-collision = {
        message = args: "${shown args "name"} is declared by more than one file, ${prose args "files"}";
        help = "rename one of the files; a name comes from the filename with its suffix dropped";
      };
    };
}
