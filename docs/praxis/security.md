# Praxis security boundaries

Praxis executes trusted project declarations with the permissions of the user
who invokes it. It is not a sandbox or an authorization system. Review a
project's commands and live scripts before running them. A hidden command,
confirmation, lock, or root check does not grant or restrict operating-system
permissions.

## Runtime credentials

Keep credentials out of Nix. A Nix string can enter the store, build logs,
manifest, derivation metadata, or cached evaluation output. Do not use
`builtins.getEnv` to turn a secret into a declaration.

Declare the source of a secret, not its value:

```nix
parameters = [ {
  name = "token";
  sensitive = true;
  required = true;
  env = "DEPLOY_TOKEN";
} ];
steps = [ {
  run = ''deploy-from-environment'';
  label = "Deploy with runtime credentials";
} ];
```

The child reads `PRAXIS_ARG_TOKEN`. If `DEPLOY_TOKEN` is absent, Praxis asks for
hidden terminal input at execution. In unattended mode it fails instead. An
optional sensitive parameter is empty in unattended mode when its environment
source is absent.

Sensitive parameters must be named strings. They cannot have static defaults,
choices, positional forms, argv references, conditions, or parameter groups.
Passing `--token VALUE` or a short alias is rejected: a CLI value can remain in
shell history or process listings before Praxis has a chance to redact it.

Within each manifest, sensitive source names and their `PRAXIS_ARG_*` names
are reserved. Ordinary parameters, static environment overrides, conditions,
and prompt responses cannot reuse them. A selected wrapper checks only its
reachable command graph; the dispatcher checks every included command.

Children do not inherit those source variables. Only an executable's active
sensitive bindings are supplied, under their `PRAXIS_ARG_*` names. Referenced
commands inherit the calling scope; unrelated commands receive no credentials.
Required bindings reject empty values even if an earlier optional binding
cached that source as empty.

Plans record only the source name and a `<sensitive>` placeholder. Help,
completion, doctor, and planning do not resolve declared sensitive bindings.
Use a dedicated source such as `DEPLOY_TOKEN`, not `PATH`, `HOME`, `CI`, or
`TERM`: the runtime and operating system still use those variables for their
ordinary configuration. Marking a name sensitive does not disable that use.

Hidden terminal input does not echo; unfinished input is discarded before echo returns,
including after timeout or cancellation. Secret-bearing executable steps have
stdout and stderr suppressed, including under verbose and JSON output.
Notifications receive a small display/session environment rather than the
command's environment, with declared sensitive names removed from that allowlist.

These measures prevent Praxis from putting a declared sensitive value in its
usual output channels. They do not protect it from the program receiving it,
from a same-user process that can inspect process memory/environment, or from
a debugger or core dump. Child programs can write files, use the network, open
the terminal themselves, or log elsewhere. Choose and configure those programs
accordingly. In-memory strings are not a secure enclave and are not guaranteed
to be zeroized.

Ordinary parameters, prompt selections, and environment overrides are not
secret. They appear in declarations or plans. Do not put credentials in prompt
messages, acknowledgement text, choices, labels, scripts, `env`, notification
argv, or `args`.

## Shell and filesystem boundaries

`exec` and `args` preserve argument boundaries; `{ param = "name"; }` inserts
one argument, not shell source. `run` is explicitly shell source. Inside a run
script, quote `"$PRAXIS_ARG_NAME"`; avoid `eval` and constructing another shell
command from untrusted text.

A live `script` path must be relative to its effective working directory.
Praxis resolves symlinks and rejects escapes from that directory. A script
without an interpreter must be executable. A previous step may create the
script, so `plan` does not require it to exist; `doctor` reports its current
availability without executing it. Live files can change between inspection
and execution. Neither command turns a mutable checkout into a verified image.

`requireRoot` checks the caller directory against the declared regular
`flake.nix` once, before execution. It rejects Nix-store directories and a
symlinked marker. This catches an accidental wrong checkout; it is not
cryptographic project identity. Use an explicit `cwd` or `discoverRoot` when
that is the behavior you need, rather than relying on a prompt to repair it.

## Cancellation and locks

Each child starts in its own process group. Signals and timeouts terminate that
group, restore terminal ownership, and reap descendants before releasing the
command's locks. Deliberately detached sessions are not covered. Do not use
Praxis to supervise a daemon.

Locks are same-user, host-local advisory locks acquired in sorted order. They
prevent overlapping Praxis invocations that name the same lock. Other tools
can ignore them; they are not distributed locks or filesystem access controls.
Files left in the private lock directory are lock inodes, not evidence that a
command is still running.

Failure stops later steps and preserves the child exit status. Effects from
completed steps remain. A timeout exits 124; a signal exits 128 plus its signal
number. There is no rollback, automatic retry, or privilege escalation.
