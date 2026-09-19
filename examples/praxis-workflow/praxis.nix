{
  pkgs,
  root,
  ...
}:
{
  commands.authenticate = {
    description = "Check a runtime credential without printing it";
    # the credential stays in runtime input instead of entering the Nix store
    parameters = [
      {
        name = "token";
        sensitive = true;
        required = true;
        env = "DEMO_TOKEN";
      }
    ];
    shell = ''test -n "$PRAXIS_ARG_TOKEN"'';
    forwardArgs = false;
  };
  tasks = {
    publish = {
      description = "Write one local publication receipt";
      confirm = "Write the local receipt?";
      lock = "praxis-doc-publish";
      timeout = 30;
      steps = [
        {
          prompt = {
            type = "select";
            name = "channel";
            message = "Choose a local channel";
            choices = [
              "preview"
              "stable"
            ];
            default = "preview";
          };
        }
        {
          label = "Write receipt";
          shell = ''
            ${pkgs.coreutils}/bin/mkdir -p .praxis-demo
            printf 'channel=%s\n' "$PRAXIS_PROMPT_CHANNEL" > .praxis-demo/receipt.txt
          '';
        }
      ];
    };
    acknowledge = {
      description = "Require an exact acknowledgement";
      steps = [
        {
          prompt = {
            type = "acknowledge";
            message = "Acknowledge this example";
            acknowledgement = "APPROVE";
          };
        }
      ];
    };
  };
}
