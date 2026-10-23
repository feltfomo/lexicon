#!/usr/bin/env python3
"""measure one evaluator process and retain rejected samples"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time


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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--component", choices=["ownerships", "registry", "declaration", "resource", "toml", "praxis", "fleet-resolve", "fleet-prepared", "fleet-custom", "fleet-trace", "fleet-matrix", "registry-queries"], required=True)
    parser.add_argument("--size", type=int, choices=[4, 16, 64], required=True)
    parser.add_argument("--bad", action="store_true")
    parser.add_argument("--initialize-report", action="store_true")
    parser.add_argument("--phase", choices=["evaluation", "render"], default="evaluation")
    parser.add_argument("--timeout-seconds", type=float, default=60)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    expression = 'import ' + str(Path(__file__).with_name("workload.nix")) + ' ' + '{ source = ' + json.dumps(args.source) + '; component = ' + json.dumps(args.component) + '; size = ' + str(args.size) + '; bad = ' + str(args.bad).lower() + '; initializeReport = ' + str(args.initialize_report).lower() + '; }'
    command = ["nix", "eval", "--impure", "--json", "--option", "allow-import-from-derivation", "false", "--extra-experimental-features", "pipe-operators", "--expr", expression]
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
        process = subprocess.Popen(command, stdout=stdout, stderr=stderr)
        try:
            signal.setitimer(signal.ITIMER_REAL, args.timeout_seconds)
            _, status, usage = os.wait4(process.pid, 0)
            process.returncode = os.waitstatus_to_exitcode(status)
        except TimeoutError:
            timed_out = True
            process.terminate()
            _, status, usage = os.wait4(process.pid, 0)
            process.returncode = os.waitstatus_to_exitcode(status)
        except BaseException:
            process.terminate()
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
                "fleet-resolve": lambda: value == [{"item" + str(i): True} for i in range(args.size)],
                "fleet-prepared": lambda: value == [{"item" + str(i): True} for i in range(args.size)],
                "fleet-custom": lambda: value == {"values": {name: True for name in names}},
                "registry-queries": lambda: value == [{"users": names, "systems": names, "hosts": names, "home": f"/home/item{i}"} for i in range(args.size)],
                "fleet-trace": lambda: validate_trace(value, args.size),
                "fleet-matrix": lambda: validate_matrix(value, args.size),
            }
            try:
                valid = decoded["component"] == args.component and decoded["size"] == args.size and validators[args.component]()
            except (KeyError, TypeError):
                valid = False
    except (ValueError, KeyError, TypeError, OSError, subprocess.CalledProcessError) as error:
        validation_error = str(error)
        valid = False
    record = {
        "command": command, "exit": process.returncode,
        "wall_seconds": completed - started,
        "closure_wall_seconds": closure_wall_seconds, "validation_error": validation_error,
        "peak_rss_kib": usage.ru_maxrss, "output_bytes": len(payload),
        "sha256": hashlib.sha256(payload).hexdigest(),
        "component": args.component, "structural_count": args.size,
        "initialize_report": args.initialize_report,
        "phase": args.phase, "rendered_bytes": rendered_bytes, "closure_bytes": closure_bytes,
        "admitted": valid and process.returncode == 0 and not timed_out,
        "timed_out": timed_out,
        "process_released": not Path(f"/proc/{process.pid}").exists(),
        "evaluator": subprocess.check_output(["nix", "--version"], text=True).strip(),
    }
    (args.output / "record.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record))
    raise SystemExit(0 if record["admitted"] else 1)


if __name__ == "__main__":
    main()
