{ entry, ... }:
entry {
  nixos =
    { host, ... }:
    {
      networking.hostName = host.name;

      nixpkgs.hostPlatform = host.system;

      system.stateVersion = host.stateVersion;

      time.timeZone = "UTC";
    };
}
