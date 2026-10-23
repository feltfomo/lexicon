{ lexicon, sources }:
lexicon {
  furnish.directories = { pkgs, ... }: [
    {
      source = sources.${pkgs.stdenv.hostPlatform.system};
      destination = ".codex/skills/bundled";
    }
  ];
  furnish.links = { user, ... }: [
    {
      source = "/home/${user.name}/Projects/skills";
      names = [
        "subphase-architect"
        "subphase-implementer"
        "subphase-orchestrator"
      ];
      destinations = [
        ".claude/skills"
        ".codex/skills"
        ".agents/skills"
      ];
    }
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
