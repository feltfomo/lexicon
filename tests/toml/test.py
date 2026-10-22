import concurrent.futures
import datetime
import importlib.util
import json
import math
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

import tomlkit

spec = importlib.util.spec_from_file_location("runtime", os.environ["LEXICON_TOML"])
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)
cli = os.environ["TOML_CLI"]
generated, retained, replacement, fixture = map(Path, sys.argv[1:])
values = tomlkit.parse(generated.read_text())
assert values["__lexiconToml"] == "ordinary application key"
assert values["" ] == "empty key" and values["a.b"] == "quoted key"
assert isinstance(values["float"], float)
assert values["plainTables"] == [{"x": 1}, {"x": 2}]
assert values["emptyTables"] == []
assert values["inline"]["tables"][0]["nested"][0]["y"] is True
assert values["precise"] == 1.2345678901234567
assert math.isinf(values["values"][0]) and math.isnan(values["values"][2])
assert math.copysign(1, values["values"][3]) < 0
assert isinstance(values["values"][4], datetime.datetime)
assert isinstance(values["values"][6], datetime.date)
assert isinstance(values["values"][7], datetime.time)
assert values["servers"][0]["child"][0]["enabled"]
assert "# retained comment" in retained.read_text()
assert "negative = -0.0" in retained.read_text()
assert tomlkit.parse(replacement.read_text())["array"] == [2]

try:
    runtime.generate({"kind": "table", "value": {"nested": {"kind": "document", "value": "x=1\n"}}})
except runtime.Error as error:
    assert "$.nested" in str(error) and "whole input" in str(error)
else:
    raise AssertionError("nested document accepted")
for text in ["9223372036854775808", "true\ninjected = 1"]:
    try:
        runtime.construct({"kind": "literal", "value": text})
    except runtime.Error:
        pass
    else:
        raise AssertionError(text)
modern = runtime.parse("inline = {\n # TOML 1.1\n value = 1,\n}\ntime = 07:32\n", "TOML1.1")
assert modern["inline"]["value"] == 1 and isinstance(modern["time"], datetime.time)
comments = runtime.merged([("first", "# original\n[a]\nx=1\n"), ("second", "# incoming\n[a]\n# nested\ny=2\n"), ("third", "# comment only\n")], "error")
assert all(comment in comments for comment in ["# original", "# incoming", "# nested", "# comment only"])
split = runtime.merged([("first", "[a.b]\nx=1\n[c]\nz=1\n[a]\ny=1\n"), ("second", "[a]\n# added\nnew=2\n")], "error")
assert tomlkit.parse(split)["a"]["new"] == 2 and "# added" in split
for conflict in ["error", "first", "last"]:
    try:
        text = runtime.merged([("first", "[a]\nx=1\n"), ("second", "a=2\n")], conflict)
    except runtime.Error as error:
        assert conflict == "error" and "$.a" in str(error) and "second" in str(error)
    else:
        assert tomlkit.parse(text)["a"] == (2 if conflict == "last" else {"x": 1})

fixture = json.loads(fixture.read_text())
assert all(a["assertion"] for a in fixture["assertions"]), fixture["assertions"]
assert tomlkit.parse(Path(fixture["example"]).read_text())["onboarding"] is False
assert "User=tester" in fixture["unit"] and "RequiresMountsFor=" in fixture["unit"]
assert fixture["User"] == "tester" and "furnish.service" in fixture["after"]
assert "furnish.service" in fixture["requires"] and len(fixture["restartTriggers"]) == 2
assert "/build/home/.config/app/config.toml" not in fixture["destinations"]
for user, registration in fixture["boundaries"].items():
    text = Path(registration).read_text()
    assert f"/build/{user}/.config/lexicon/toml/" in text
assert len(fixture["destinations"]) == len(set(fixture["destinations"]))
noctalia = tomlkit.parse(Path(fixture["noctalia"]).read_text())["theme"]["templates"]["user"]["test-one"]
matugen = tomlkit.parse(Path(fixture["matugen"]).read_text())["templates"]["test"]
assert noctalia["output_path"].startswith("~/.local/state/lexicon/toml/")
assert matugen["output_path"].startswith("/build/home/.local/state/lexicon/toml/")
assert "lexicon-toml publish" in noctalia["post_hook"] and "lexicon-toml publish" in matugen["post_hook"]
assert ".local/state/lexicon/toml/" in Path(fixture["caelestia"]).read_text()

# Execute emitted entrypoints under their declared principal home. HOME is
# inherited unchanged; composed hooks carry their bound absolute paths.
service_command = shlex.split(fixture["ExecStart"])
installed_descriptor = Path(service_command[-1])
installed_descriptor.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(fixture["descriptor"], installed_descriptor)
published = Path(json.loads(installed_descriptor.read_text())["output"])
subprocess.run(service_command, check=True, timeout=20)
assert tomlkit.parse(published.read_text())["operational"] is True

def run_hook(hook):
    subprocess.run(hook, shell=True, executable=fixture["shell"], check=True, timeout=20)

noctalia_staging = Path(noctalia["output_path"].replace("~/", "/build/home/", 1))
noctalia_staging.parent.mkdir(parents=True, exist_ok=True)
noctalia_staging.write_text('[theme]\nbackground="noctalia"\n')
run_hook(noctalia["post_hook"])
assert tomlkit.parse(published.read_text())["theme"]["background"] == "noctalia"
new_base = published.parent / "new-base.toml"
new_base.write_text("operational=false\ncommands=[3]\n")
current_descriptor = json.loads(installed_descriptor.read_text())
current_descriptor["base"] = str(new_base)
installed_descriptor.write_text(json.dumps(current_descriptor))
subprocess.run(service_command, check=True, timeout=20)
assert tomlkit.parse(published.read_text())["operational"] is False
# An old renderer hook must still use the new installed base.
run_hook(noctalia["post_hook"])
assert tomlkit.parse(published.read_text())["operational"] is False
matugen_staging = Path(matugen["output_path"])
matugen_staging.write_text('[theme]\nbackground="matugen"\n')
run_hook(matugen["post_hook"])
subprocess.run(service_command, check=True, timeout=20)
assert tomlkit.parse(published.read_text())["theme"]["background"] == "matugen"
caelestia_staging = Path("/build/home/.local/state/caelestia/theme/test-palette.toml")
caelestia_staging.parent.mkdir(parents=True, exist_ok=True)
caelestia_staging.write_text('[theme]\nbackground="caelestia"\n')
subprocess.run([fixture["caelestia"]], check=True, timeout=20)
assert tomlkit.parse(published.read_text())["theme"]["background"] == "caelestia"

with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    descriptor = root / "current.json"
    base = root / "base.toml"
    theme = root / "staging.toml"
    output = root / "config.toml"
    state = root / "state"
    reloads = root / "reloads"
    config = {"base": str(base), "output": str(output), "state": str(state), "conflict": "error", "shell": "/bin/sh", "reload": f"echo yes >> {reloads}"}
    descriptor.write_text(json.dumps(config))
    base.write_text("operational=1\nremoved=1\ncommands=[1,2]\n")
    def invoke(*args, success=True):
        result = subprocess.run([cli, "publish", str(descriptor), *args], capture_output=True, text=True, timeout=20)
        assert (result.returncode == 0) == success, result.stderr
        return result
    invoke()
    assert tomlkit.parse(output.read_text())["operational"] == 1
    theme.write_text('[theme]\nbackground="first"\n')
    invoke("--theme", str(theme))
    base.write_text("operational=2\ncommands=[3]\n")
    invoke()
    current = tomlkit.parse(output.read_text())
    assert current["operational"] == 2 and "removed" not in current
    assert current["theme"]["background"] == "first" and current["commands"] == [3]
    theme.write_text('[theme]\nbackground="other backend"\n')
    invoke("--theme", str(theme))
    invoke()
    assert tomlkit.parse(output.read_text())["theme"]["background"] == "other backend"
    before = output.stat().st_mtime_ns
    reload_count = reloads.read_text()
    invoke()
    assert output.stat().st_mtime_ns == before and reloads.read_text() == reload_count
    previous = output.read_bytes()
    theme.write_text("broken = [")
    invoke("--theme", str(theme), success=False)
    assert output.read_bytes() == previous
    invoke()
    config["reload"] = "exit 7"
    descriptor.write_text(json.dumps(config))
    base.write_text("operational=3\n")
    invoke(success=False)
    assert (state / "reload-pending").exists()
    config["reload"] = f"echo retry >> {reloads}"
    descriptor.write_text(json.dumps(config))
    invoke()
    assert not (state / "reload-pending").exists() and "retry" in reloads.read_text()
    environment_file = root / "environment"
    config["reload"] = f"printf '%s\n%s\n' \"$XDG_RUNTIME_DIR\" \"$DBUS_SESSION_BUS_ADDRESS\" > {environment_file}"
    descriptor.write_text(json.dumps(config))
    base.write_text("operational=4\n")
    old_getuid = runtime.os.getuid
    runtime.os.getuid = lambda: 12345
    try:
        runtime.publish(descriptor)
    finally:
        runtime.os.getuid = old_getuid
    assert environment_file.read_text().splitlines() == ["/run/user/12345", "unix:path=/run/user/12345/bus"]
    # Accepted theme state is the recovery authority after an interrupted final write.
    output.write_text("stale=true\n")
    invoke()
    assert tomlkit.parse(output.read_text())["operational"] == 4
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        list(pool.map(lambda _: invoke(), range(18)))
    assert not list(root.rglob(".lexicon-toml-*"))
    distinct = []
    for number in range(8):
        candidate = root / f"theme-{number}.toml"
        candidate.write_text(f"[theme]\nnumber={number}\n")
        distinct.append(candidate)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(lambda path: invoke("--theme", str(path)), distinct))
    final = tomlkit.parse(output.read_text())
    cached = tomlkit.parse((state / "accepted.toml").read_text())
    assert final["theme"] == cached["theme"] and final["operational"] == 4
    assert not list(root.rglob(".lexicon-toml-*"))
    old_atomic = runtime.atomic
    failed_theme = root / "interrupted.toml"
    failed_theme.write_text('[theme]\nbackground="accepted before interruption"\n')
    def fail_output(path, data, mode=0o600):
        if Path(path) == output:
            raise OSError("injected destination write failure")
        return old_atomic(path, data, mode)
    runtime.atomic = fail_output
    previous = output.read_bytes()
    try:
        try:
            runtime.publish(descriptor, failed_theme)
        except OSError:
            pass
        else:
            raise AssertionError("injected output failure didn't occur")
    finally:
        runtime.atomic = old_atomic
    assert output.read_bytes() == previous
    invoke()
    assert tomlkit.parse(output.read_text())["theme"]["background"] == "accepted before interruption"
    previous = output.read_bytes()
    (state / "accepted.toml").write_text("bad=[")
    invoke(success=False)
    assert output.read_bytes() == previous
    (state / "accepted.toml").write_text('[theme]\nbackground="recovered"\n')
    output.unlink()
    output.symlink_to(base)
    invoke(success=False)
    assert output.is_symlink()
print("TOML API, generated Program hooks/services and publication lifecycle passed")
