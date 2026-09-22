# the interior reads an entity and a module-system argument, so a placement
# short of either fails the evaluation
{ entry, ... }:
entry {
  nixos =
    { pkgs, host, ... }:
    {
      networking.hostName = host.name;

      environment.systemPackages = [ pkgs.hello ];

      fileSystems."/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };

      boot.loader.grub.enable = false;

      system.stateVersion = "24.05";
    };
}
