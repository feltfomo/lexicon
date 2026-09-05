import copy
import json
import os
from pathlib import Path
import pty
import resource
import select
import signal
import subprocess
import sys
import tempfile
import time

runner, source, executables, modular = sys.argv[1:]
manifest = json.loads(Path(source).read_text())

def invoke(*args, cwd, expected=0, selected=source, executable=None, input=None, dispatcher=None):
    if dispatcher is not None:
        command = [dispatcher, *args]
    elif executable is not None:
        command = [str(Path(executables) / executable), *args]
    else:
        command = [runner, "--manifest", str(selected), *args]
    result = subprocess.run(command, cwd=cwd, input=input, text=True, capture_output=True, timeout=15)
    assert result.returncode == expected, (command, result.returncode, result.stdout, result.stderr)
    return result

def changed(root, name, edit):
    value = copy.deepcopy(manifest)
    edit(value)
    path = root / f"{name}.json"
    path.write_text(json.dumps(value))
    return path

with tempfile.TemporaryDirectory(prefix="praxis ") as directory:
    root = Path(directory)
    (root / "nested").mkdir()
    (root / "flake.nix").write_text("{}")
    modular_plan = json.loads(invoke("plan", "gate", cwd=root / "nested", dispatcher=modular).stdout)
    assert [step["command"] for step in modular_plan["steps"]] == ["fmt", "test"]
    assert all(step["cwd"] == str(root) for step in modular_plan["steps"])
    assert modular_plan["steps"][1]["script"] == "scripts/test.sh"
    assert not (root / "scripts").exists()
    build_plan = json.loads(invoke("plan", "build", ".#a b", "--", "--show-trace", cwd=root, dispatcher=modular).stdout)
    assert build_plan["steps"][0]["program"] == "nix"
    assert build_plan["steps"][0]["args"] == ["build", ".#a b", "--show-trace"]
    (root / "scripts").mkdir()
    (root / "scripts/test.sh").write_text('printf "<%s>" "$@"\n')
    assert invoke("run", "test", "--", "a b", "", cwd=root / "nested", dispatcher=modular).stdout == "<a b><>"
    invoke(cwd=root, executable="sequence")
    assert (root / "trace").read_text() == "first\nfirst\nlast\nlast\n"
    (root / "trace").unlink()
    invoke("run", "preflight", cwd=root, expected=64)
    assert not (root / "trace").exists()
    plan = json.loads(invoke("plan", "sequence", cwd=root).stdout)
    assert [step["command"] for step in plan["steps"]] == ["first", "first", "last", "last"]
    assert not (root / "trace").exists()
    value = "two ' words $(touch injected)\nend"
    response = invoke("run", "literal", value, "--count=-7", "--colorize", "--destination=a b", "--", "", "--flag", cwd=root)
    assert json.loads(response.stdout) == [[value, "-7", "", "--flag"], "true", "a b"]
    assert not (root / "injected").exists()
    assert json.loads(invoke("run", "forwarding", "--", "--only-child", cwd=root).stdout)[0] == ["nested literal", "4", "--only-child"]
    for args in [("run", "literal"), ("run", "literal", "word", "--count=oops"), ("run", "literal", "word", "--count=1", "--count=2"), ("run", "sequence", "--", "stray")]:
        invoke(*args, cwd=root, expected=64)
    assert "--count" in invoke("--help", cwd=root, executable="literal").stdout
    assert "sequence" in invoke("list", cwd=root).stdout
    invoke("run", "confirm", cwd=root, expected=64)
    assert invoke("run", "confirm", "--yes", cwd=root).stdout == "accepted"
    result = invoke("run", "plain", "--plain", cwd=root)
    assert result.stdout == "data" and "child error" in result.stderr and "\x1b" not in result.stderr
    invoke("run", "fail", cwd=root, expected=23)
    assert not (root / "should-not-run").exists()
    assert invoke("run", "cwd", cwd=root).stdout.strip() == str(root / "nested")
    assert invoke("run", "interactive", cwd=root, input="piped\n").stdout == "received:piped\n"
    explicit = changed(root, "cwd", lambda value: value["project"].update(cwd=str(root)))
    assert invoke("run", "cwd", cwd=root / "nested", selected=explicit).stdout.strip() == str(root / "nested")
    (root / "marker").write_text("")
    discovered = changed(root, "discovery", lambda value: value["project"].update(discoverRoot="marker"))
    assert invoke("run", "cwd", cwd=root / "nested", selected=discovered).stdout.strip() == str(root / "nested")
    for shell in ["fish", "bash", "zsh"]:
        completion = invoke("completions", shell, cwd=root).stdout
        assert "literal" in completion and "complete" in completion
        if shell != "zsh":
            subprocess.run([shell, "-n"], input=completion, text=True, check=True)
    def limit_descriptors():
        resource.setrlimit(resource.RLIMIT_NOFILE, (32, 32))

    quick = changed(root, "quick", lambda value: value["commands"]["first"].update(
        steps=[dict(value["commands"]["first"]["steps"][0], run="true") for _ in range(128)]))
    result = subprocess.run([runner, "--manifest", str(quick), "run", "first"], cwd=root,
                            capture_output=True, timeout=15, preexec_fn=limit_descriptors)
    assert result.returncode == 0, result.stderr
    bad_version = changed(root, "version", lambda value: value.update(version=999))
    invoke("list", cwd=root, selected=bad_version, expected=65)
    missing = changed(root, "missing", lambda value: value["commands"]["sequence"]["steps"][0].update(command="missing"))
    invoke("run", "sequence", cwd=root, selected=missing, expected=64)
    cycle = changed(root, "cycle", lambda value: value["commands"]["sequence"]["steps"][0].update(command="sequence"))
    invoke("run", "sequence", cwd=root, selected=cycle, expected=65)
    assert not (root / "trace").exists()
    process = subprocess.Popen([runner, "--manifest", source, "run", "cancel"], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        deadline = time.monotonic() + 8
        while not (root / "ready").exists():
            assert process.poll() is None and time.monotonic() < deadline
            time.sleep(0.02)
        child = int((root / "descendant").read_text())
        invoke("run", "locked", cwd=root, expected=75)
        process.send_signal(signal.SIGTERM)
        _, stderr = process.communicate(timeout=8)
        assert process.returncode == 143, stderr
        assert not (root / "should-not-run").exists()
        try:
            os.kill(child, 0)
        except ProcessLookupError:
            pass
        else:
            raise AssertionError("descendant survived cancellation")
    finally:
        if process.poll() is None:
            process.kill()
            process.communicate(timeout=5)
            if (root / "descendant").exists():
                try:
                    os.killpg(os.getpgid(int((root / "descendant").read_text())), signal.SIGKILL)
                except ProcessLookupError:
                    pass
    assert invoke("run", "locked", cwd=root).stdout == "unlocked"
    pid, terminal = pty.fork()
    if pid == 0:
        os.chdir(root)
        os.execv(runner, [runner, "--manifest", source, "run", "interactive"])
    transcript = b""
    status = None
    sent = False
    deadline = time.monotonic() + 10
    try:
        while time.monotonic() < deadline:
            readable, _, _ = select.select([terminal], [], [], 0.1)
            if readable:
                try:
                    transcript += os.read(terminal, 4096)
                except OSError:
                    break
            if b"running" in transcript and not sent:
                os.write(terminal, b"terminal\n")
                sent = True
            waited, value = os.waitpid(pid, os.WNOHANG)
            if waited:
                status = value
                break
        if status is None:
            waited, value = os.waitpid(pid, os.WNOHANG)
            if waited:
                status = value
        assert status == 0 and b"received:terminal" in transcript, (status, transcript)
    finally:
        os.close(terminal)
        if status is None:
            try:
                os.kill(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
            except ProcessLookupError:
                pass
print("praxis runtime integration passed")
