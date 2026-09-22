# the boilerplate half of a host that evaluates. the second interior beside
# it is what this fixture exists for
{ entry, ... }:
entry {
  nixos =
    { host, ... }:
    {
      networking.hostName = host.name;

      fileSystems."/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };

      boot.loader.grub.enable = false;

      system.stateVersion = "24.05";
    };
}
