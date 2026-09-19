{ program }:
program {
  # users.users is ordinary module content rather than a Program selection claim
  nixos.users.users.river.isNormalUser = true;
}
