# a file under one subsystem's tree naming a check after every entry the
# walk read. only the names are read, never what an entry built
{ fleet, lexicon, ... }:
fleet {
  checks = builtins.listToAttrs (
    map (name: {
      name = "reached-${name}";
      value = {
        steps = [
          {
            name = "seal";
            run = "mkdir -p $out";
          }
        ];
      };
    }) (builtins.attrNames lexicon)
  );
}
