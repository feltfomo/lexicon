{ entry, ... }:
entry {
  nixos =
    { lib, host, ... }:
    {
      # host.users holds what each person's file wrote
      users.users = lib.mapAttrs (
        _: written:
        {
          isNormalUser = true;
          extraGroups = lib.optional (written.elevated or false) "wheel";
        }
        // lib.optionalAttrs (written ? shell) { inherit (written) shell; }
      ) host.users;
    };
}
