{ program, sources }:
program {
  directories = { pkgs, ... }: [
    {
      src = sources.${pkgs.stdenv.hostPlatform.system};
      dest = ".codex/skills/bundled";
    }
  ];
  links =
    { user, ... }:
    map
      (name: {
        target = "/home/${user.name}/Projects/skills/${name}";
        dest = ".codex/skills/${name}";
      })
      [
        "subphase-architect"
        "subphase-implementer"
        "subphase-orchestrator"
      ];
  homeManager = { pkgs, user, ... }: {
    systemd.user.services.skills-bootstrap = {
      Unit = {
        Description = "Clone editable skills";
        ConditionPathExists = "!/home/${user.name}/Projects/skills";
      };
      Service = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /home/${user.name}/Projects";
        ExecStart = "${pkgs.git}/bin/git clone https://github.com/feltfomo/skills /home/${user.name}/Projects/skills";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
