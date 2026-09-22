# the entity is read only where the module system reads a definition value,
# so nothing here needs it before the option set exists
{ entry, ... }:
entry {
  nixos =
    { host, ... }:
    {
      networking.hostName = host.name;

      environment.variables = {
        LEXICON_CLASS = host.class;
        LEXICON_USERS = toString (builtins.attrNames host.users);
      };

      fileSystems."/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };

      boot.loader.grub.enable = false;

      system.stateVersion = "24.05";
    };
}
