import importlib.util
import json
import math
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

import tomlkit

spec = importlib.util.spec_from_file_location("runtime", os.environ["LEXICON_TOML"])
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)
cli = os.environ["TOML_CLI"]
fixtures = json.loads(Path(sys.argv[1]).read_text())
integration = json.loads(Path(sys.argv[2]).read_text())


def oracle(node):
    kind, value = node["kind"], node["value"]
    if kind == "table":
        return {key: oracle(item) for key, item in value.items()}
    if kind == "array":
        return [oracle(item) for item in value]
    if kind in ("inline", "tables"):
        return oracle(value)
    if kind == "document":
        return tomlkit.parse(value).unwrap()
    if kind == "literal":
        return runtime.literal(value, "oracle").unwrap()
    if kind == "float":
        spelling = value if any(c in value for c in ".eE") else value + ".0"
        return tomlkit.parse("value=" + spelling).unwrap()["value"]
    assert kind == "scalar"
    return value


def equal(actual, expected):
    if isinstance(expected, dict):
        return actual.keys() == expected.keys() and all(equal(actual[k], v) for k, v in expected.items())
    if isinstance(expected, list):
        return len(actual) == len(expected) and all(equal(a, b) for a, b in zip(actual, expected))
    if isinstance(expected, float):
        return isinstance(actual, float) and (
            math.isnan(actual) if math.isnan(expected) else actual == expected
            and (expected != 0 or math.copysign(1, actual) == math.copysign(1, expected))
        )
    return type(actual) is type(expected) and actual == expected


def invoke(command, success=True, environment=None):
    result = subprocess.run(command, capture_output=True, text=True, timeout=30, env=environment)
    assert result.returncode == (0 if success else 1), (command, result.returncode, result.stdout, result.stderr)
    return result


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    source, output = root / "input.json", root / "output.toml"
    environment = os.environ.copy()
    original_home = environment.get("HOME")
    environment.update(NIX_REMOTE="unix:///no-nix-daemon", NIX_PATH="", NIX_USER_CONF_FILES="/no-nix-config")
    environment["NIX_CONFIG"] = "store = unix:///no-nix-daemon\nsubstituters =\nflake-registry = /no-registry\n"
    for name, fixture in fixtures.items():
        rendered = fixture["rendered"]
        actual = tomlkit.parse(runtime.validated(rendered)).unwrap()
        assert equal(actual, oracle(fixture["encoded"])), name
        source.write_text(json.dumps(fixture["encoded"]))
        invoke([cli, "generate", str(source), str(output)], environment=environment)
        assert output.read_bytes() == rendered["text"].encode(), name
        assert environment.get("HOME") == original_home

    scalar = lambda value: {"kind": "scalar", "value": value}
    table = lambda value: {"kind": "table", "value": value}
    data = '${builtins.abort "evaluated input"}; $(touch ' + str(root / "injected") + '); $HOME'
    numeric = table({
        "precise": scalar(1.2345678901234567), "negative": scalar(-0.0),
        "inf": scalar(float("inf")), "nan": scalar(float("nan")),
        "maximum": scalar(2**63-1), "minimum": scalar(-(2**63)), "data": scalar(data),
    })
    source.write_text(json.dumps(numeric))
    invoke([cli, "generate", str(source), str(output)], environment=environment)
    parsed = tomlkit.parse(output.read_text()).unwrap()
    assert parsed["precise"] == 1.2345678901234567 and math.copysign(1, parsed["negative"]) < 0
    assert math.isinf(parsed["inf"]) and math.isnan(parsed["nan"])
    assert parsed["maximum"] == 2**63-1 and parsed["minimum"] == -(2**63)
    assert parsed["data"] == data and not (root / "injected").exists()

    invalid = [
        table({"x": {"kind": "literal", "value": "true\ninjected=1"}}),
        table({"x": {"kind": "literal", "value": "true\r\ninjected=1"}}),
        table({"x": {"kind": "literal", "value": "9223372036854775808"}}),
        table({"x": {"kind": "float", "value": "1.0\ninjected=1"}}),
        table({"x": scalar(2**63)}), table({"x": scalar(None)}),
        {"kind": "document", "value": "broken=["},
        table({"x": {"kind": "document", "value": "x=1"}}),
    ]
    for node in invalid:
        source.write_text(json.dumps(node))
        output.write_text("previous output\n")
        invoke([cli, "generate", str(source), str(output)], success=False, environment=environment)
        assert output.read_text() == "previous output\n"
    source.write_text(json.dumps(table({"safe": scalar(True)})))
    failed = invoke([integration["sentinelCli"], "generate", str(source), str(output)], success=False)
    assert "evaluator-sentinel" in failed.stderr and output.read_text() == "previous output\n"
    environment["LEXICON_EXPECTED_HOME"] = original_home or ""
    invoke([integration["homeCli"], "generate", str(source), str(output)], environment=environment)

    first, second = root / "first.toml", root / "second.toml"
    first.write_text("# retained\n[a.b]\nx=0x1_0\n[c]\nz=1\n[a]\ny=-0.0\n")
    second.write_text("# incoming\n[a]\nnew=2\n")
    invoke([integration["sentinelCli"], "merge", str(output), str(first), str(second)])
    merged = output.read_text()
    assert all(text in merged for text in ["# retained", "# incoming", "0x1_0", "-0.0"])
    for before, incoming, key in [
        ("x=1\n", "x=1\n", "x"),
        ("[a]\nx=1\n", "a=2\n", "a"),
        ("a=2\n", "[a]\nx=1\n", "a"),
        ("a=[1,2]\n", "a=[3]\n", "a"),
        ("[[a]]\nx=1\n", "[[a]]\ny=2\n", "a"),
    ]:
        first.write_text(before)
        second.write_text(incoming)
        for policy in ["error", "first", "last"]:
            output.write_text("unchanged\n")
            result = invoke([integration["sentinelCli"], "merge", "--conflict", policy, str(output), str(first), str(second)], success=policy != "error")
            if policy == "error":
                assert output.read_text() == "unchanged\n" and f"$.{key}" in result.stderr
            else:
                chosen = incoming if policy == "last" else before
                assert tomlkit.parse(output.read_text()) == tomlkit.parse(chosen)
    first.write_text("current=0\n")

    descriptor = root / "descriptor.json"
    destination = root / "published.toml"
    config = {"state": str(root / "state"), "base": str(first), "output": str(destination), "conflict": "error"}
    descriptor.write_text(json.dumps(config))
    invoke([integration["sentinelCli"], "publish", str(descriptor)])
    destination.chmod(0o640)
    first.write_text("current=1\n")
    invoke([integration["sentinelCli"], "publish", str(descriptor)])
    assert stat.S_IMODE(destination.stat().st_mode) == 0o640
    before = destination.stat().st_mtime_ns
    invoke([integration["sentinelCli"], "publish", str(descriptor)])
    assert before == destination.stat().st_mtime_ns

    replacement = root / "replacement.toml"
    replacement.write_text("current=2\n")
    old_flock = runtime.fcntl.flock
    def update_under_lock(fd, operation):
        old_flock(fd, operation)
        descriptor.write_text(json.dumps(config | {"base": str(replacement)}))
    runtime.fcntl.flock = update_under_lock
    try:
        runtime.publish(descriptor)
    finally:
        runtime.fcntl.flock = old_flock
    assert tomlkit.parse(destination.read_text())["current"] == 2

assert tomlkit.parse(Path(integration["recovered"]).read_text())["recovered"] is True
assert tomlkit.parse(Path(integration["finished"]).read_text())["finished"] is True
assert tomlkit.parse(Path(integration["opaqueSource"]).read_text()) == {"generated": True, "extra": True}
assert tomlkit.parse(Path(integration["packagedContext"]).read_text())["executable"].endswith("/bin/true")
print("renderer oracle, installed CLI, evaluator isolation and publication boundaries passed")
