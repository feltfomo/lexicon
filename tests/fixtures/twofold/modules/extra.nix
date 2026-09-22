# the second interior on the same host, reading the entity the placement
# binds so both interiors need the binding
{ entry, ... }:
entry {
  nixos =
    { host, ... }:
    {
      environment.variables.LEXICON_HOST = host.name;
    };
}
