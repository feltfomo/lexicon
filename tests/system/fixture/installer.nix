{ inputs }:
{
  config,
  pkgs,
  modulesPath,
  ...
}:
let
  disko = inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko;
  install = pkgs.writeShellApplication {
    name = "lexicon-install";
    runtimeInputs = [
      disko
      pkgs.coreutils
      pkgs.git
      pkgs.nixos-install-tools
    ];
    text = ''
      source="''${LEXICON_INSTALL_SOURCE:-/tmp/lexicon-furnish}"
      host="''${1:-furnish-vm}"
      disko --yes-wipe-all-disks --mode destroy,format,mount --flake "$source#$host"
      toplevel="$(nix build --no-link --print-out-paths "$source#nixosConfigurations.$host.config.system.build.toplevel")"
      nixos-install --root /mnt --system "$toplevel" --no-root-passwd
    '';
  };
in
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  # the harness is serial-only, so do not enter GRUB's graphical menu.
  isoImage.forceTextMode = true;
  # keep VGA as a fallback while making the captured serial port primary.
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200n8"
  ];

  networking.hostName = "furnish-installer";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIElUx+G8NdV6W0NVEh3wpOg33mBnHY0oG9b31eds/LSs furnish-vm-test"
  ];

  environment.systemPackages = [
    disko
    install
  ];
}
