{
  config,
  pkgs,
  ...
}:
{

  networking.hostName = "furnish-vm";
  system.stateVersion = "26.05";

  boot = {
    loader = {
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
      };
      efi.canTouchEfiVariables = true;
    };
    initrd = {
      availableKernelModules = [
        "virtio_pci"
        "virtio_blk"
        "virtio_scsi"
        "ahci"
        "sd_mod"
      ];
      systemd = {
        enable = true;
        contents."/luks.key".source = pkgs.writeText "furnish-vm-luks-key" "disko";
        services.rollback = {
          description = "restore the blank furnish test root";
          wantedBy = [ "initrd.target" ];
          after = [ "systemd-cryptsetup@cryptroot.service" ];
          before = [ "sysroot.mount" ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = ''
            mkdir -p /btrfs
            mount -t btrfs /dev/mapper/cryptroot /btrfs
            if [ -e /btrfs/@ ]; then
              mkdir -p /btrfs/@old
              mv /btrfs/@ /btrfs/@old/$(date +%s)
            fi
            ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot /btrfs/@blank /btrfs/@
            umount /btrfs
          '';
        };
      };
      luks.devices.cryptroot.keyFile = "/luks.key";
    };
    kernelParams = [
      "console=tty0"
      "console=ttyS0,115200"
    ];
  };

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    gc.automatic = false;
  };

  users.users.tester = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPassword = "$6$skadivmtest$tp5BUeNDHy1miR21O7X2QXROL/yxzqnT9XeKJ4UKI.PpyYdkise0/iV58ErEoKs5SuKbvW/xy93Mzu3lQ2Fgf0";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIElUx+G8NdV6W0NVEh3wpOg33mBnHY0oG9b31eds/LSs furnish-vm-test"
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };
  users.users.root.openssh.authorizedKeys.keys =
    config.users.users.tester.openssh.authorizedKeys.keys;

  lexicon.furnish = {
    enable = true;
    state = {
      path = "/persist/var/lib/furnish";
      durability = "durable";
      requiresMountsFor = [ "/persist" ];
    };
  };

  environment.systemPackages = [
    pkgs.git
    pkgs.jq
  ];
}
