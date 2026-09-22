# what a subsystem hands this layer, described once. the registration is read
# as strictly as anything a caller writes
{ fx, t }:
let
  Name = t.refined "SubsystemName" t.String (fx.types.matching "[a-z][a-z0-9-]*");

  Filename = t.refined "SettingsFilename" t.String (fx.types.matching "[a-z][a-z0-9-]*[.]nix");

  # the schema is an attrset of key declarations, each carrying the type its
  # value is read against and the value a file that stays silent gets
  Registration = t.bless (
    fx.types.Record {
      name = Name;
      filename = Filename;
      schema = t.Attrs;
    }
  );
in
{
  inherit
    Name
    Filename
    Registration
    ;
}
