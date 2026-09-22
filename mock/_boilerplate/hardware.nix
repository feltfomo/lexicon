# one block of hardware settings per value a machine writes in its hardware
# field
{
  desktop = {
    fileSystems."/" = {
      device = "/dev/sda2";
      fsType = "ext4";
    };

    boot.loader.grub = {
      enable = true;
      device = "/dev/sda";
    };
  };

  laptop = {
    fileSystems."/" = {
      device = "/dev/nvme0n1p2";
      fsType = "ext4";
    };

    boot.loader.systemd-boot.enable = true;

    powerManagement.enable = true;
  };

  virtual = {
    fileSystems."/" = {
      device = "/dev/vda1";
      fsType = "ext4";
    };

    boot.loader.grub = {
      enable = true;
      device = "/dev/vda";
    };
  };

  generic = {
    fileSystems."/" = {
      device = "/dev/disk/by-label/root";
      fsType = "ext4";
    };

    boot.loader.grub.enable = false;
  };
}
