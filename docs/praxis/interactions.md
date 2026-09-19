# Interactions and workflow policy

Add interaction only after the underlying command or task is useful without it. Confirmation, selection, timeouts, and locks each solve a different runtime problem.

## Use focused policies

<!-- source: ../../examples/praxis-workflow/praxis.nix -->
```nix
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
```

Task-level `confirm` runs once before the task actions. An action-level `confirm` guards only that action. A prompt action may be a yes/no confirmation, an exact acknowledgement, or a selection. A named selection is exported to later actions as `PRAXIS_PROMPT_<NAME>`.

For unattended use, `--yes` accepts confirmation prompts. A selection still needs a declared default, and an acknowledgement still requires a terminal and an exact response. `--non-interactive` rejects any interaction that cannot be resolved safely.

<!-- praxis-command: workflow.publish -->
```sh
praxis --yes --non-interactive --quiet publish
cat .praxis-demo/receipt.txt
```

<!-- praxis-output: workflow.receipt -->
```text
channel=preview
```

`lock` prevents concurrent workflows with the same command-style lock name. Command and action `timeout` values are positive seconds and terminate the active process group when their shared budget expires.

## Conditions and interaction metadata

`condition` may match declared parameter values, runtime platforms, or environment values. Conditions skip actions whose requirements do not match; they do not rewrite the action. `interactive = true` gives an executable the terminal and is rejected in non-interactive or CI execution.

Aliases, categories, hidden declarations, deprecation notices, examples, and descriptions affect discovery and help. Project, command, and action `ui` values can select `concise`, `verbose`, `quiet`, `plain`, or `json` output, color and progress policy, and success or failure notifications. Runner flags override those declarations for one invocation.

## Protect sensitive parameters

A sensitive parameter is a runtime-only named string input. Use an environment source or terminal input; do not embed a secret in the declaration.

Sensitive parameters:

- cannot have static defaults or choices;
- cannot be positional or use a non-string type;
- cannot enter argv, parameter groups, or conditions;
- reserve their protected environment names from ordinary defaults, overrides, prompt results, and conditions;
- suppress child stdout and stderr while the sensitive value is active.

<!-- praxis-command: workflow.authenticate -->
```sh
DEMO_TOKEN=test-only praxis --quiet authenticate
```

The command succeeds without printing the token or child output. Exhaustive prompt, notification, collision, and propagation semantics are in the [reference](reference.md#interactions-ui-and-sensitive-inputs).

Next, learn how to [inspect commands and plans](runtime.md) before execution.
