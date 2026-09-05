import copy
import json
import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import sys
import tempfile
import termios
import time

runner, source, executables, snapshots_path = sys.argv[1:]
snapshots = json.loads(Path(snapshots_path).read_text())
manifest = json.loads(Path(source).read_text())
base_env = dict(os.environ)
base_env.pop("CI", None)
base_env["PATH"] = executables + os.pathsep + base_env["PATH"]

def invoke(*args, root, expected=0, env=None, selected=source):
    result = subprocess.run([runner, "--manifest", str(selected), *args], cwd=root,
                            env=base_env | (env or {}), text=True, capture_output=True, timeout=15)
    assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
    return result

def changed(root, name, edit):
    value = copy.deepcopy(manifest)
    edit(value)
    path = root / (name + ".json")
    path.write_text(json.dumps(value))
    return path

def terminal(root, args, responses=(), expected=0, env=None, selected=source):
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(root)
        os.execve(runner, [runner, "--manifest", str(selected), *args], base_env | (env or {}))
    transcript, sent, status = b"", 0, None
    deadline = time.monotonic() + 10
    try:
        while time.monotonic() < deadline:
            if select.select([fd], [], [], 0.05)[0]:
                try:
                    block = os.read(fd, 8192)
                    transcript += block
                except OSError:
                    break
            if sent < len(responses) and responses[sent][0] in transcript:
                os.write(fd, responses[sent][1])
                sent += 1
            waited, value = os.waitpid(pid, os.WNOHANG)
            if waited:
                status = value
                break
        if status is None:
            for _ in range(40):
                waited, value = os.waitpid(pid, os.WNOHANG)
                if waited:
                    status = value
                    break
                time.sleep(0.025)
        assert status is not None and os.waitstatus_to_exitcode(status) == expected, (status, transcript)
        assert termios.tcgetattr(fd)[3] & termios.ECHO, transcript
        return transcript
    finally:
        os.close(fd)
        if status is None:
            try:
                os.kill(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
            except ProcessLookupError:
                pass

with tempfile.TemporaryDirectory(prefix="praxis-interaction-") as directory:
    root = Path(directory)
    assert invoke("--help", root=root).stdout == snapshots["help"]
    assert invoke("run", "ch", "-mrelease", root=root).stdout == "release"
    assert invoke("run", "choose", root=root, env={"PRAXIS_TEST_MODE": "two words"}).stdout == "two words"
    assert invoke("run", "choose", "--mode=debug", root=root, env={"PRAXIS_TEST_MODE": "release"}).stdout == "debug"
    invoke("run", "choose", "--mode=nope", root=root, expected=64)
    invoke("run", "choose", root=root, env={"PRAXIS_TEST_MODE": "nope"}, expected=64)
    assert "hidden\t" not in invoke("list", root=root).stdout
    assert "hidden\t" in invoke("list", "--all", root=root).stdout
    assert "deprecated" in invoke("run", "old", root=root).stderr
    details = invoke("show", "choose", root=root).stdout
    for word in ["choices: debug, release, two words", "env: PRAXIS_TEST_MODE", "Aliases: ch", "Examples:", "Print mode"]:
        assert word in details, details
    invoke("run", "groups", "--one=a", "--two=b", root=root, expected=64)
    invoke("run", "groups", "--two=b", root=root, expected=64)
    assert invoke("run", "groups", "--two=b", "--three=c", root=root).stdout == "grouped"
    assert invoke("run", "conditions", root=root).stdout == ""
    assert invoke("run", "conditions", "--enabled", root=root).stdout == "parameter"
    assert invoke("run", "conditions", root=root, env={"PRAXIS_TEST_ENV": "match"}).stdout == "environment"
    assert invoke("run", "selection", "--non-interactive", root=root).stdout == "local"
    assert not (root / "remote").exists()
    for flags in [(), ("--yes",), ("--non-interactive",)]:
        invoke("run", "acknowledgement", *flags, root=root, expected=64)
    invoke("run", "confirm-step", "--non-interactive", root=root, expected=64)
    assert invoke("run", "confirm-step", "--yes", "--non-interactive", root=root).stdout == "approved"
    invoke("run", "interactive", "--non-interactive", root=root, expected=64)
    terminal(root, ["run", "acknowledgement", "--yes"], [(b"[type DELETE]", b"DELETE\n")])
    assert (root / "approved").exists()
    (root / "approved").unlink()
    terminal(root, ["run", "acknowledgement"], [(b"[type DELETE]", b"wrong\n")], expected=64)
    assert not (root / "approved").exists()
    terminal(root, ["run", "confirm-step"], [(b"[y/N]", b"n\n")], expected=64)
    terminal(root, ["run", "confirm-step"], [(b"[y/N]", b"yes\n")])
    terminal(root, ["run", "selection"], [(b"Choose target", b"2\n")])
    assert (root / "remote").exists()
    terminal(root, ["run", "confirm-step"], expected=64, env={"CI": "1"})
    terminal(root, ["run", "prompt-timeout"], expected=124)
    terminal(root, ["run", "confirm-step"], [(b"[y/N]", b"\x03")], expected=130)
    secret = "test-only-credential-\u2603"
    plan = invoke("plan", "secret", root=root, env={"PRAXIS_TEST_TOKEN": secret}).stdout
    assert secret not in plan and "<sensitive>" in plan
    invoke("run", "secret", "--token=" + secret, root=root, expected=64)
    invoke("run", "secret", "--non-interactive", root=root, expected=64)
    result = invoke("run", "secret", "--verbose", root=root, env={"PRAXIS_TEST_TOKEN": secret})
    assert secret not in result.stdout + result.stderr and (root / "secret-used").exists()
    transcript = terminal(root, ["run", "secret"], [(b"token:", (secret + "\n").encode())])
    assert secret.encode() not in transcript, transcript
    for name in ["timeout", "command-timeout", "nested-timeout"]:
        invoke("run", name, root=root, expected=124)
        assert not (root / "after-timeout").exists()
    child = int((root / "timeout-child").read_text())
    try:
        os.kill(child, 0)
    except ProcessLookupError:
        pass
    else:
        raise AssertionError("timeout left a descendant")
    (root / "notify.py").write_text("import json,os,sys\nfrom pathlib import Path\nPath('notification').write_text(json.dumps([sys.argv[1:], 'PRAXIS_TEST_TOKEN' in os.environ]))\n")
    invoke("run", "notify", root=root, env={"PRAXIS_TEST_TOKEN": secret})
    assert json.loads((root / "notification").read_text()) == [["Praxis", "notify succeeded"], False]
    invoke("run", "notify-fail", root=root, expected=23)
    assert json.loads((root / "notification").read_text())[0][-1] == "notify-fail failed"
    (root / "notification").unlink()
    invoke("run", "notify", "--notify=never", root=root)
    assert not (root / "notification").exists()
    bell = terminal(root, ["run", "choose", "--bell"])
    assert b"\x07" in bell
    result = invoke("run", "choose", "--quiet", root=root)
    assert result.stdout == "debug" and result.stderr == ""
    result = invoke("run", "choose", "--json", root=root)
    events = [json.loads(line) for line in result.stdout.splitlines()]
    assert [event["event"] for event in events] == snapshots["runEvents"]
    assert result.stderr == "debug" and events[-1]["success"]
    assert "ok " in invoke("doctor", "choose", root=root).stdout
    invoke("doctor", "cwd", root=root, expected=1)
    assert not (root / "trace").exists()
    for shell in ["fish", "bash", "zsh"]:
        completion = invoke("completions", shell, root=root).stdout
        subprocess.run([shell, "-n"], input=completion, text=True, check=True, env=base_env)
        (root / (shell + ".completion")).write_text(completion)
    for words in [("run", "choose", "--mode", ""), ("run", "ch", "-m", "")]:
        assert invoke("complete", "--", *words, root=root).stdout.splitlines() == ["debug", "release", "two words"]
    assert invoke("complete", "--", "run", "choose", "--mode=r", root=root).stdout == "--mode=release\n"
    fish = subprocess.run(["fish", "-c", "source fish.completion; complete -C 'praxis run choose --mode r'"], cwd=root, env=base_env, text=True, capture_output=True, check=True)
    assert "release" in fish.stdout, fish
    bash = subprocess.run(["bash", "-c", "source bash.completion; COMP_WORDS=(praxis run choose --mode r); COMP_CWORD=4; _praxis_complete; printf '%s\\n' \"${COMPREPLY[@]}\""], cwd=root, env=base_env, text=True, capture_output=True, check=True)
    assert bash.stdout == "release\n", bash
    # snapshots omit timings and checkout-dependent paths
    assert invoke("complete", "--", "run", "choose", "--mode=", root=root).stdout == snapshots["choiceCandidates"]
    global_values = changed(root, "global-values", lambda m: m["commands"]["choose"]["parameters"][0].update(choices=["debug", "--yes", "--json"]))
    assert invoke("run", "choose", "--mode", "--json", root=root, selected=global_values).stdout == "--json"
    assert invoke("--quiet", "run", "choose", root=root).stderr == ""
    missing_default = changed(root, "no-default", lambda m: m["commands"]["selection"]["steps"][0]["prompt"].update(default=None))
    invoke("run", "selection", "--yes", root=root, selected=missing_default, expected=64)
    inherited = changed(root, "inherited", lambda m: m["commands"]["sequence"]["steps"][0].update(when={"env": {"PRAXIS_TEST_ENV": "missing"}}))
    invoke("run", "sequence", root=root, selected=inherited)
    assert (root / "trace").read_text().splitlines() == ["first", "last", "last"]
    (root / "trace").unlink()
    released = changed(root, "released", lambda m: m["commands"]["timeout"].update(steps=[dict(m["commands"]["first"]["steps"][0], run="true")]))
    invoke("run", "timeout", root=root, selected=released)
    unavailable = changed(root, "unavailable", lambda m: m["commands"]["notify"]["ui"]["notifications"].update(command=["/not-an-executable"]))
    assert "unavailable" in invoke("run", "notify", root=root, selected=unavailable).stderr
    scoped = changed(root, "scoped", lambda m: (m["project"].update(ui={"output":"quiet"}), m["commands"]["choose"]["steps"][0].update(ui={"output":"verbose"})))
    assert "cwd=" in invoke("run", "choose", root=root, selected=scoped).stderr
    assert invoke("run", "choose", "--quiet", root=root, selected=scoped).stderr == ""
    failed = invoke("run", "notify-fail", "--json", root=root, expected=23)
    failure_events = [json.loads(line) for line in failed.stdout.splitlines()]
    assert failure_events[-1]["event"] == "error" and failure_events[-1]["code"] == 23
    zsh = subprocess.run(["zsh", "-c", "autoload -Uz compinit; compinit -D; source zsh.completion; compadd() { shift; print -rl -- \"$@\"; }; words=(praxis run choose --mode r); CURRENT=5; _praxis_complete"], cwd=root, env=base_env, text=True, capture_output=True, check=True)
    assert zsh.stdout == "release\n", zsh
    snapshot = json.loads(invoke("show", "choose", "--json", root=root).stdout)
    assert {key: snapshot["declaration"][key] for key in ["category", "aliases", "examples", "hidden", "deprecated"]} == {
        "category": "build", "aliases": ["ch"], "examples": ["praxis run choose -m release"], "hidden": False, "deprecated": None}
    for flag in ["-m", "-m=", "-m--json"]:
        args = [flag, "--json"] if flag == "-m" else [flag + "--json"] if flag == "-m=" else [flag]
        assert invoke("run", "choose", *args, root=root, selected=global_values).stdout == "--json"
    for words in [("--output", "plain", "run", "choose", "-mr"),
                  ("run", "ch", "--color", "never", "-m=r"),
                  ("run", "choose", "--output", "plain", "--mode=r")]:
        assert "release" in invoke("complete", "--", *words, root=root).stdout
    assert invoke("complete", "--", "--output", "j", root=root).stdout == "json\n"
    assert invoke("complete", "--", "run", "choose", "--notify=f", root=root).stdout == "--notify=failure\n"
    assert invoke("complete", "--", "run", "choose", "--", "", root=root).stdout == ""
    for words, index, expected in [
        ("praxis run choose --mode = r", 5, "release\n"),
        ("praxis run choose --mode =", 4, "debug\nrelease\ntwo words\n"),
    ]:
        script = f"source bash.completion; COMP_WORDS=({words}); COMP_CWORD={index}; _praxis_complete; printf '%s\\n' \"${{COMPREPLY[@]}}\""
        result = subprocess.run(["bash", "-c", script], cwd=root, env=base_env, text=True, capture_output=True, check=True)
        assert result.stdout == expected, result

    def run_step(script, **fields):
        return dict(copy.deepcopy(manifest["commands"]["first"]["steps"][0]), run=script, label="Test action", **fields)

    def numeric_command(m):
        command = m["commands"]["choose"]
        command["parameters"] = [dict(command["parameters"][0], name="count", type="int", short="n", env=None, choices=["2"], default="2")]
        command["steps"] = [run_step('printf %s "$PRAXIS_ARG_COUNT"', when={"parameters": {"count": "2"}})]
    numeric = changed(root, "numeric", numeric_command)
    assert invoke("run", "choose", "-n+02", root=root, selected=numeric).stdout == "2"
    invoke("run", "choose", "-n3", root=root, selected=numeric, expected=64)
    plain_plan = invoke("plan", "choose", "--plain", root=root, selected=numeric).stdout
    assert 'parameters [choose]: count="2"' in plain_plan and "when: parameters match" in plain_plan

    def positional_numbers(m):
        numeric_command(m)
        command = m["commands"]["choose"]
        command["parameters"][0].update(positional=True, short=None, choices=["-2", "-20", "2"])
        command["steps"][0]["when"]["parameters"]["count"] = "-2"
    negative = changed(root, "negative-positional", positional_numbers)
    assert invoke("run", "choose", "-02", root=root, selected=negative).stdout == "-2"
    assert invoke("complete", "--", "run", "choose", "--output", "plain", "-2", root=root, selected=negative).stdout == "-2\n-20\n"
    candidates = invoke("complete", "--", "run", "choose", "-", root=root, selected=negative).stdout.splitlines()
    assert {"-2", "-20", "--help"}.issubset(candidates)

    def groups_with_defaults(m):
        for p in m["commands"]["groups"]["parameters"]:
            if p["name"] == "two":
                p.update(default="fallback", env="PRAXIS_GROUP_TWO")
    grouped = changed(root, "group-defaults", groups_with_defaults)
    invoke("run", "groups", root=root, selected=grouped)
    invoke("run", "groups", root=root, selected=grouped, env={"PRAXIS_GROUP_TWO": ""}, expected=64)
    invoke("run", "groups", "--three=c", root=root, selected=grouped, env={"PRAXIS_GROUP_TWO": ""})
    non_unicode = changed(root, "non-unicode", lambda m: m["commands"]["choose"].update(steps=[
        run_step("printf absent", when={"env": {"PRAXIS_NON_UNICODE": None}})]))
    assert invoke("run", "choose", root=root, selected=non_unicode, env={"PRAXIS_NON_UNICODE": b"\xff"}).stdout == ""
    terminal(root, ["run", "acknowledgement"], [(b"[type DELETE]", b" DELETE\n")], expected=64)
    terminal(root, ["run", "confirm-step"], [(b"[y/N]", b"\x04")], expected=64)
    terminal(root, ["run", "selection"], expected=0, env={"CI": ""})
    secret_timeout = changed(root, "secret-timeout", lambda m: m["commands"]["secret"].update(timeout=1))
    for payload, code in [(b"unfinished-credential", 124), (b"\x04", 64), (b"\x03", 130)]:
        transcript = terminal(root, ["run", "secret"], [(b"token:", payload)], expected=code, selected=secret_timeout)
        assert b"unfinished-credential" not in transcript
    assert "--token VALUE" not in invoke("show", "secret", root=root).stdout

    isolated = changed(root, "isolated", lambda m: m["commands"]["choose"].update(steps=[
        run_step('printf "%s|%s" "${PRAXIS_TEST_TOKEN-unset}" "${PRAXIS_ARG_TOKEN-unset}"')]))
    result = invoke("run", "choose", root=root, selected=isolated, env={"PRAXIS_TEST_TOKEN": secret, "PRAXIS_ARG_TOKEN": secret})
    assert result.stdout == "unset|unset" and secret not in result.stderr
    scoped_secret = changed(root, "scoped-secret", lambda m: m["commands"]["secret"].update(steps=[
        run_step('test -n "$PRAXIS_ARG_TOKEN" && test -z "${PRAXIS_TEST_TOKEN+x}" && touch token-scoped')]))
    invoke("run", "secret", root=root, selected=scoped_secret, env={"PRAXIS_TEST_TOKEN": secret})
    assert (root / "token-scoped").exists()
    for action in ["show", "plan", "doctor"]:
        result = invoke(action, "secret", root=root, env={"PRAXIS_TEST_TOKEN": b"\xff"})
        assert secret not in result.stdout + result.stderr
    for name, edit in [
        ("secret-default", lambda m: m["commands"]["choose"]["parameters"][0].update(env="PRAXIS_TEST_TOKEN")),
        ("secret-destination", lambda m: m["commands"]["choose"]["parameters"][0].update(name="token")),
        ("secret-override", lambda m: m["commands"]["choose"]["steps"][0].update(env={"PRAXIS_TEST_TOKEN": "literal"})),
        ("secret-condition", lambda m: m["commands"]["choose"]["steps"][0].update(when={"env": {"PRAXIS_TEST_TOKEN": None}})),
    ]:
        selected = changed(root, name, edit)
        result = invoke("plan", "choose", root=root, selected=selected, env={"PRAXIS_TEST_TOKEN": secret}, expected=65)
        assert secret not in result.stdout + result.stderr

    def cached_required(m):
        optional = copy.deepcopy(m["commands"]["secret"])
        optional["parameters"][0]["required"] = False
        optional["steps"] = [run_step("true")]
        m["commands"]["optional-secret"] = optional
        reference = copy.deepcopy(m["commands"]["sequence"]["steps"][0])
        m["commands"]["sequence"]["steps"] = [dict(reference, command="optional-secret"), dict(reference, command="secret")]
    cached = changed(root, "cached-required", cached_required)
    result = invoke("run", "sequence", "--non-interactive", root=root, selected=cached, expected=64)
    assert "required sensitive input is empty" in result.stderr
    (root / "notify.py").write_text("import os\nfrom pathlib import Path\nPath('notification-home').write_text(str('HOME' in os.environ))\n")
    protected_home = changed(root, "protected-home", lambda m: m["commands"]["secret"]["parameters"][0].update(env="HOME"))
    invoke("run", "notify", root=root, selected=protected_home, env={"HOME": secret})
    assert (root / "notification-home").read_text() == "False"
    (root / "slow-notify.py").write_text("import time\ntime.sleep(60)\n")
    slow_notify = changed(root, "slow-notify", lambda m: m["commands"]["notify"]["ui"]["notifications"].update(command=[sys.executable, "slow-notify.py"]))
    before = time.monotonic()
    assert "unavailable" in invoke("run", "notify", root=root, selected=slow_notify).stderr
    assert time.monotonic() - before < 9

    accounted = changed(root, "accounting", lambda m: m["commands"]["choose"].update(steps=[
        run_step("true", when={"parameters": {"mode": "release"}}), run_step("true"),
        run_step("exit 23"), run_step("touch after-failure")]))
    result = invoke("run", "choose", "--json", root=root, selected=accounted, expected=23)
    summary = next(event for event in map(json.loads, result.stdout.splitlines()) if event["event"] == "finished")
    assert {key: summary[key] for key in snapshots["failedRun"]} == snapshots["failedRun"]
    assert not (root / "after-failure").exists()
    result = invoke("run", "choose", "--json", "--mode=nope", root=root, expected=64)
    assert json.loads(result.stdout) == snapshots["choiceError"]

    special_values = ["debug", "two words", "O'Reilly", "$(touch escaped)", "semi;colon", "-dash", "trailing\\", "界"]
    special = changed(root, "special-choices", lambda m: m["commands"]["choose"]["parameters"][0].update(choices=special_values + ["tab\tvalue", "\x1b[31m"]))
    assert set(invoke("complete", "--", "run", "choose", "--mode", "", root=root, selected=special).stdout.splitlines()) == set(special_values)
    for name, prefix in [("praxis", []), ("choose", ["run", "choose"])]:
        executable = root / name
        executable.write_text(f"#!{sys.executable}\nimport os,sys\nos.execv({runner!r}, {[runner, '--manifest', str(special), *prefix]!r} + sys.argv[1:])\n")
        executable.chmod(0o700)
    shell_env = base_env | {"PATH": str(root) + os.pathsep + base_env["PATH"]}
    for executable in ["praxis", str(root / "praxis"), "choose", str(root / "choose")]:
        words = [executable, "run", "choose", "--mode", ""] if Path(executable).name == "praxis" else [executable, "--mode", ""]
        script = 'source bash.completion; COMP_WORDS=("$@"); COMP_CWORD=$((${#COMP_WORDS[@]} - 1)); _praxis_complete; printf "%s\\n" "${COMPREPLY[@]}"'
        result = subprocess.run(["bash", "-c", script, "bash", *words], cwd=root, env=shell_env, text=True, capture_output=True, check=True)
        assert set(result.stdout.splitlines()) == set(special_values), result
        script = 'autoload -Uz compinit; compinit -D; source zsh.completion; compadd() { [[ $1 == -- ]] || return 1; shift; print -rl -- "$@"; }; words=("$@"); CURRENT=${#words[@]}; _praxis_complete'
        result = subprocess.run(["zsh", "-c", script, "zsh", *words], cwd=root, env=shell_env, text=True, capture_output=True, check=True)
        assert set(result.stdout.splitlines()) == set(special_values), result
    fish = subprocess.run(["fish", "-c", "source fish.completion; complete -C \"$argv[1] run choose --mode \" | string split -f1 \\t | string unescape", "--", str(root / "praxis")], cwd=root, env=shell_env, text=True, capture_output=True, check=True)
    assert set(fish.stdout.splitlines()) == set(special_values), fish
    assert not (root / "escaped").exists()
print("praxis interaction, security, completion and snapshot tests passed")
