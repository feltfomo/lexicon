#!/usr/bin/env python3
"""measure one evaluator process and retain rejected samples"""

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time


# counting is enabled only through the environment, so inherited values would silently combine modes
COUNTING_ENVIRONMENT = ("NIX_SHOW_STATS", "NIX_COUNT_CALLS", "NIX_SHOW_STATS_PATH", "NIX_SHOW_SYMBOLS")
SAMPLING_HZ = 1000


def profile_contracts():
    path = Path(__file__).with_name("profile-contracts.py")
    spec = importlib.util.spec_from_file_location("profile_contracts", path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def bound_identities(directory, names):
    return {name: hashlib.sha256((directory / name).read_bytes()).hexdigest() if (directory / name).is_file() else None
            for name in names}


def validate_trace(value, size):
    leaves = []
    for i in range(size):
        for child in range(2):
            rejected = (["host"] if i else []) + (["when"] if child else [])
            leaves.append({"checks": 0, "key": f"0/{i}/{child}", "selected": not rejected, "rejectedBy": rejected})
    return value == {"value": {"values": {"item0": True}}, "leaves": leaves,
                     "stages": {"leaf": 3, "tree": 0, "survivors": 0}}


def validate_matrix(value, size):
    contexts = [f"fleet/item{i}/user" for i in range(size)]
    by_context = {}
    for i, context in enumerate(contexts):
        inactive = []
        for j in range(size):
            for child in range(2):
                rejected = (["host"] if i != j else []) + (["when"] if child else [])
                if rejected:
                    inactive.append({"key": f"leaf-{2*j+child}", "rejectedBy": rejected})
        by_context[context] = {"hostName": f"fleet/item{i}", "userName": "user", "inactive": inactive,
                               "preMergePaths": ["values"], "survivors": [f"leaf-{2*i}"]}
    diffs = {}
    for i in range(size):
        for j in range(size):
            if f"fleet/item{i}" < f"fleet/item{j}":
                diffs[f"fleet/item{i} -> fleet/item{j}"] = {
                    "units": {"leftOnly": [f"leaf-{2*i}"], "rightOnly": [f"leaf-{2*j}"]},
                    "preMergePaths": {"leftOnly": [], "rightOnly": []}}
    return value == {"byContext": by_context, "hostDiffs": diffs, "dead": 0, "never": size,
                     "coverage": {"units": {f"leaf-{2*i+c}": [contexts[i]] if c == 0 else []
                                            for i in range(size) for c in range(2)},
                                  "preMerge": {"meaning": "top-level paths offered by surviving leaves before merge",
                                               "paths": {"values": contexts}}}}


def compiler_expected(component, size):
    field = "hm" if component in ("compiler-single", "compiler-combined") else "entries"
    def home(marker):
        entries = []
        for i in range(size):
            origin = ["sample"] + [part for _ in range(i) for part in ("next", 1)] if component == "compiler-deep" else ["sample", field, i + 1]
            entries.append({"n": i + 1, "defaulted": 7, "tag": i + 10, "origin": origin, "prepared": i})
        return {"entries": entries, "context": marker, "output": "homeManager"}
    if component == "compiler-prepared":
        return [home(i) for i in range(size)]
    if component == "compiler-combined":
        return {"home": home("home"), "resources": [{"destination": f".sample/{i+1}", "source": f"/external/{i+1}"} for i in range(size)]}
    return home(0)


def resource_expected(component, size):
    def directory(principal):
        return [{"destination": f".tree/item{i}/default.nix", "representation": "writable", "principal": principal}
                for i in range(size)]
    return {
        "resource-directory": lambda: directory("user"),
        "resource-shared": lambda: [directory(f"user{i}") for i in range(size)],
        "resource-grouped": lambda: [".ordinary"] + [f".{root}/item{i}" for root in ("a", "b") for i in range(size)],
        "resource-theme": lambda: {
            "destinations": [f".config/matugen/dms/templates/item{i}/safe-render.nix" for i in reversed(range(size))] + [".config/matugen/config.toml"],
            "templates": {f"item{i}": {"output_path": f"/home/user/.output/item{i}"} for i in range(size)}},
        "resource-furnish": lambda: [{"destination": f"/home/user/.files/item{i}",
                                      "target": {"kind": "external", "path": f"/external/item{i}"},
                                      "executor": {"identity": "component/executor", "protocolVersion": 1}}
                                     for i in sorted(range(size), key=lambda i: f"item{i}")],
        "resource-index": lambda: sorted(f"x86_64-linux/host:/home/user/.files/item{i}" for i in range(size)),
    }[component]()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--component", choices=["ownerships", "registry", "declaration", "resource", "toml", "praxis", "praxis-selected", "praxis-diagnostics", "fleet-resolve", "fleet-prepared", "fleet-custom", "fleet-trace", "fleet-matrix", "registry-queries", "compiler-wide", "compiler-deep", "compiler-prepared", "compiler-dynamic", "compiler-single", "compiler-combined", "resource-directory", "resource-shared", "resource-grouped", "resource-theme", "resource-furnish", "resource-index"], required=True)
    parser.add_argument("--size", type=int, choices=[4, 16, 64], required=True)
    parser.add_argument("--bad", action="store_true")
    parser.add_argument("--initialize-report", action="store_true")
    parser.add_argument("--output-projection", choices=["default", "missing", "unsupported"], default="default")
    parser.add_argument("--phase", choices=["evaluation", "render"], default="evaluation")
    parser.add_argument("--timeout-seconds", type=float, default=60)
    parser.add_argument("--dispatcher", type=Path)
    parser.add_argument("--bind", action="append", default=[], metavar="NAME=SHA256")
    parser.add_argument("--instrumentation", choices=["none", "flamegraph", "counts"], default="none")
    args = parser.parse_args()
    dispatcher = args.dispatcher or Path(__file__).with_name("workload.nix")
    bindings = {}
    for item in args.bind:
        name, _, digest = item.partition("=")
        if not re.fullmatch(r"[A-Za-z0-9._-]+", name) or not re.fullmatch(r"[0-9a-f]{64}", digest) or name in bindings:
            parser.error(f"malformed binding {item}")
        bindings[name] = digest
    if args.dispatcher is not None and (not args.dispatcher.is_absolute() or args.dispatcher.name not in bindings):
        parser.error("an explicit dispatcher needs an absolute path and a binding for its own identity")
    if bound_identities(dispatcher.parent, bindings) != bindings:
        parser.error("bound dispatcher files don't match their identities")
    if args.instrumentation != "none":
        # ordinary capture keeps inheriting the caller's environment as it always has
        inherited = [name for name in COUNTING_ENVIRONMENT if name in os.environ]
        if inherited or re.search(r"eval-profil|trace-function-calls", os.environ.get("NIX_CONFIG", "")):
            parser.error(f"inherited evaluator instrumentation {inherited or 'NIX_CONFIG'} would combine capture modes")
        if args.phase == "render":
            parser.error("instrumentation is only supported for the evaluation phase")
    contracts = profile_contracts() if args.instrumentation != "none" else None
    args.output.mkdir(parents=True, exist_ok=False)
    if args.output_projection != "default" and not args.component.startswith(("compiler-", "resource-")):
        parser.error("output projection controls require a compiler or resource workload")
    expression = 'import ' + str(dispatcher) + ' ' + '{ source = ' + json.dumps(args.source) + '; component = ' + json.dumps(args.component) + '; size = ' + str(args.size) + '; bad = ' + str(args.bad).lower() + '; initializeReport = ' + str(args.initialize_report).lower() + '; outputProjection = ' + json.dumps(args.output_projection) + '; }'
    instrumented = None
    environment = {}
    options = []
    if args.instrumentation == "flamegraph":
        instrumented = (args.output / "profile.folded").resolve()
        options = ["--option", "eval-profiler", "flamegraph", "--option", "eval-profiler-frequency", str(SAMPLING_HZ),
                   "--option", "eval-profile-file", str(instrumented)]
    elif args.instrumentation == "counts":
        instrumented = (args.output / "stats.json").resolve()
        # sampling stays explicitly off so a configured profiler can't run beside the counters
        options = ["--option", "eval-profiler", "disabled"]
        environment = {"NIX_SHOW_STATS": "1", "NIX_COUNT_CALLS": "1", "NIX_SHOW_STATS_PATH": str(instrumented)}
    command = ["nix", "eval", "--impure", "--json", "--option", "allow-import-from-derivation", "false", "--extra-experimental-features", "pipe-operators", *options, "--expr", expression]
    if args.phase == "render":
        if args.component != "toml":
            parser.error("render phase is only supported for TOML")
        expression = expression[:-1] + " artifact = true; }"
        command = ["nix", "build", "--no-link", "--impure", "--json", "--extra-experimental-features", "pipe-operators", "--expr", expression]
    started = time.monotonic()
    timed_out = False
    def expired(_signal, _frame):
        raise TimeoutError("component evaluator exceeded its limit")
    signal.signal(signal.SIGALRM, expired)
    with (args.output / "stdout").open("wb") as stdout, (args.output / "stderr").open("wb") as stderr:
        launch_marker_ns = None
        if instrumented is not None:
            # the directory's coarse filesystem clock, not time.time_ns, is comparable with the record's mtime
            launch_marker_ns = args.output.stat().st_mtime_ns
            if instrumented.exists():
                raise RuntimeError(f"instrumentation destination already exists {instrumented}")
        process = subprocess.Popen(command, stdout=stdout, stderr=stderr, env=dict(os.environ, **environment) if environment else None)
        try:
            signal.setitimer(signal.ITIMER_REAL, args.timeout_seconds)
            _, status, usage = os.wait4(process.pid, 0)
            process.returncode = os.waitstatus_to_exitcode(status)
        except TimeoutError:
            timed_out = True
            # nix only acts on SIGTERM at its next interrupt check, which evaluation may never reach,
            # so the limit is enforced with a signal it can't defer and no teardown runs past it
            process.kill()
            _, status, usage = os.wait4(process.pid, 0)
            process.returncode = os.waitstatus_to_exitcode(status)
        except BaseException:
            process.kill()
            process.wait()
            raise
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)
    completed = time.monotonic()
    payload = (args.output / "stdout").read_bytes()
    valid = False
    rendered_bytes = None
    closure_bytes = None
    validation_error = None
    closure_wall_seconds = None
    try:
        if process.returncode == 0 and args.phase == "render":
            built = json.loads(payload)
            path = built[0]["outputs"]["out"]
            rendered = Path(path).read_bytes()
            (args.output / "rendered.toml").write_bytes(rendered)
            import tomllib
            valid = tomllib.loads(rendered.decode()) == {f"item{i}": 1 for i in range(args.size)}
            rendered_bytes = len(rendered)
            closure_started = time.monotonic()
            closure = subprocess.check_output(["nix", "path-info", "--json", "--closure-size", path])
            (args.output / "closure.json").write_bytes(closure)
            closure_wall_seconds = time.monotonic() - closure_started
            closure_bytes = next(iter(json.loads(closure).values()))["closureSize"]
        elif process.returncode == 0:
            decoded = json.loads(payload)
            names = sorted(f"item{i}" for i in range(args.size))
            value = decoded.get("value")
            validators = {
                "ownerships": lambda: value == {"values": {name: True for name in names}},
                "registry": lambda: value == {"hosts": names, "users": [], "systems": ["x86_64-linux"]},
                "declaration": lambda: value == [{"environment": {name: True for name in names}}],
                "resource": lambda: value == [f".links/item{i}" for i in range(args.size)],
                "toml": lambda: isinstance(value, str) and value.startswith("/nix/store/") and value.endswith("-component"),
                "praxis": lambda: value["version"] == 2 and sorted(value["commands"]) == names,
                "praxis-selected": lambda: value["version"] == 2 and sorted(value["commands"]) == ["gate"] + sorted("ops." + name for name in names)
                    and [step["command"] for step in value["commands"]["gate"]["steps"]] == [f"ops.item{i}" for i in range(args.size)]
                    and all(value["commands"]["ops." + name]["parameters"][0]["default"] == "7" for name in names),
                "praxis-diagnostics": lambda: value == {"codes": ["praxis/args-shape"] * (2 * args.size), "paths": [[0]] * (2 * args.size),
                    "summary": {"total": 2 * args.size, "hasErrors": True, "byCode": {"praxis/args-shape": 2 * args.size}, "bySeverity": {"error": 2 * args.size, "warning": 0, "info": 0}}},
                "fleet-resolve": lambda: value == [{"item" + str(i): True} for i in range(args.size)],
                "fleet-prepared": lambda: value == [{"item" + str(i): True} for i in range(args.size)],
                "fleet-custom": lambda: value == {"values": {name: True for name in names}},
                "registry-queries": lambda: value == [{"users": names, "systems": names, "hosts": names, "home": f"/home/item{i}"} for i in range(args.size)],
                "fleet-trace": lambda: validate_trace(value, args.size),
                "fleet-matrix": lambda: validate_matrix(value, args.size),
            }
            try:
                if args.component.startswith("resource-"):
                    projection_valid = value == resource_expected(args.component, args.size)
                elif args.output_projection == "missing":
                    projection_valid = value == {"nixos": [], "homeManager": [], "resources": []}
                else:
                    projection_valid = value == compiler_expected(args.component, args.size) if args.component.startswith("compiler-") else validators[args.component]()
                valid = decoded["component"] == args.component and decoded["size"] == args.size and projection_valid
            except (KeyError, TypeError):
                valid = False
    except (ValueError, KeyError, TypeError, OSError, subprocess.CalledProcessError) as error:
        validation_error = str(error)
        valid = False
    released = not Path(f"/proc/{process.pid}").exists()
    evaluator = subprocess.check_output(["nix", "--version"], text=True).strip()
    instrumentation = {"mode": "none"}
    if contracts is not None:
        instrumentation = contracts.capture(args.instrumentation, instrumented, launch_marker_ns, evaluator)
        instrumentation.update(environment=environment, options=options)
    unchanged = bound_identities(dispatcher.parent, bindings) == bindings
    record = {
        "command": command, "exit": process.returncode,
        "wall_seconds": completed - started,
        "closure_wall_seconds": closure_wall_seconds, "validation_error": validation_error,
        "peak_rss_kib": usage.ru_maxrss, "output_bytes": len(payload),
        "sha256": hashlib.sha256(payload).hexdigest(),
        "component": args.component, "structural_count": args.size,
        "initialize_report": args.initialize_report,
        "output_projection": args.output_projection,
        "phase": args.phase, "rendered_bytes": rendered_bytes, "closure_bytes": closure_bytes,
        "admitted": valid and process.returncode == 0 and not timed_out
                    and instrumentation.get("valid", True) and unchanged,
        "timed_out": timed_out,
        "process_released": released,
        "evaluator": evaluator,
        "dispatcher": {"path": str(dispatcher), "bindings": bindings, "unchanged_after_release": unchanged},
        "instrumentation": instrumentation,
    }
    (args.output / "record.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record))
    raise SystemExit(0 if record["admitted"] else 1)


if __name__ == "__main__":
    main()
