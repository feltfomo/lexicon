"""check ownership callbacks, demand and original exceptions with a real evaluator"""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser()
    inputs = parser.add_mutually_exclusive_group(required=True)
    inputs.add_argument("--source")
    inputs.add_argument("--setup", type=Path)
    parser.add_argument("--baseline", action="store_true")
    parser.add_argument("--reference", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    if args.source:
        fixture = Path(__file__).resolve().parents[2] / "tests/ownerships/observations.nix"
        setup = ('let p = builtins.getFlake ' + json.dumps(args.source) + '; lib = p.inputs.nixpkgs.lib; '
                 'axiom = p.inputs.axiom.lib.axiom { inherit lib; }; in import ' + str(fixture)
                 + ' { inherit lib axiom; ownerships = p.lib.ownerships; }')
    else:
        setup = "import " + str(args.setup.resolve())
    expected = {
        "prepared": {"first": {"values": [0, 1]}, "repeat": {"values": [0, 1]}, "second": {"values": [0, 1]}},
        "ordinary": {"first": {"values": [0, 1]}, "second": {"values": [0, 1]}},
        "trace": {"value": {"a": True, "b": True}, "keys": ["0/0", "0/1"], "stageReports": {
            "leaf": [{"view": "leaf", "diagnostics": []}] * 2,
            "tree": [{"view": "tree", "diagnostics": []}],
            "survivors": [{"view": "survivors", "diagnostics": []}]}},
        "matrix": {"contexts": ["standalone/a", "standalone/b"],
                   "coverage": {"leaf-0": ["standalone/a", "standalone/b"], "leaf-1": ["standalone/a", "standalone/b"]}},
        "lazy": "lambda", "poison": True, "leftFold": {"x": 123}, "listFold": {"x": [1, 2, 3]},
    }
    callbacks = {
        "leftFold": {"registration": 1, "scalar": 2},
        "listFold": {"registration": 1, "list": 2},
        "prepared": {"registration": 1, "schema parent": 1, "schema child": 1, "predicate": 4},
        "ordinary": {"registration": 1, "schema parent": 2, "schema child": 2, "predicate": 4},
        "trace": {"registration": 1, "one a": 1, "one b": 1, "two a": 1, "two b": 1, "tree": 1, "survivors": 1},
        "matrix": {"registration": 1, "one a": 1, "one b": 1, "two a": 1, "two b": 1, "tree": 1, "survivors": 2},
    }
    if args.baseline:
        for cell, count in {"prepared": 4, "ordinary": 6, "trace": 3, "matrix": 5, "leftFold": 3, "listFold": 3}.items():
            callbacks[cell]["registration"] = count
    exception_markers = {name: f"fleet {name} exception" for name in ["selector", "scalar", "list", "stage", "shape", "scope", "import"]}
    exception_markers.update({"static": "claim can never be satisfied", "scopeFirst": "a system-scope (host-only) unit sets 'users'",
                              "shapeFirst": "'hosts' must be a list of names", "registration": 'ownerships: unknown stage view "bad"'})
    records = []
    for cell in list(expected) + ["exceptions." + name for name in exception_markers]:
        command = ["nix", "eval", "--impure", "--json", "--show-trace", "--extra-experimental-features", "nix-command flakes pipe-operators",
                   "--option", "allow-import-from-derivation", "false", "--expr", "(" + setup + ")." + cell]
        if args.setup:
            command.extend(["--store", "dummy://"])
        started = time.monotonic()
        timed_out = False
        try:
            run = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
            stdout, raw_stderr, exit_code = run.stdout, run.stderr, run.returncode
        except subprocess.TimeoutExpired as error:
            timed_out = True
            stdout, raw_stderr, exit_code = error.stdout or b"", error.stderr or b"", None
        elapsed = time.monotonic() - started
        (args.output / (cell + ".stdout")).write_bytes(stdout)
        (args.output / (cell + ".stderr")).write_bytes(raw_stderr)
        stderr = raw_stderr.decode()
        events = re.findall(r"^trace: fleet (.*)$", stderr, re.MULTILINE)
        if cell in expected:
            try:
                admitted = exit_code == 0 and json.loads(stdout) == expected[cell]
            except (ValueError, TypeError):
                admitted = False
            if cell in callbacks:
                counts = {event: events.count(event) for event in callbacks[cell]}
                admitted = admitted and counts == callbacks[cell]
                order = [event for event in events if event.startswith(("one ", "two "))]
                if cell == "trace":
                    admitted = admitted and order == ["one a", "one b", "two a", "two b"]
                if cell == "matrix":
                    admitted = admitted and order == ["one a", "two a", "one b", "two b"]
        else:
            marker = exception_markers[cell.split(".")[1]]
            terminal = stderr.rsplit("error: ", 1)[-1]
            admitted = exit_code is not None and exit_code != 0 and marker in terminal and "premature" not in terminal
            if args.reference:
                reference = (args.reference / (cell + ".stderr")).read_text().rsplit("error: ", 1)[-1]
                admitted = admitted and terminal == reference
            if cell == "exceptions.selector":
                admitted = admitted and "while evaluating 'when' predicate" in stderr
            if cell == "exceptions.import":
                admitted = admitted and "while importing ownership units" in stderr
        record = {"cell": cell, "command": command, "exit": exit_code, "wall_seconds": elapsed,
                  "events": events, "timed_out": timed_out, "admitted": bool(admitted) and not timed_out}
        records.append(record)
        (args.output / "records.json").write_text(json.dumps(records, indent=2) + "\n")
        if not admitted:
            print("\n".join(stderr.splitlines()[-30:]), file=sys.stderr)
            raise RuntimeError(f"ownership contract failed {cell}; see {args.output}")
    print(json.dumps({"checks": len(records), "all_admitted": True}))


if __name__ == "__main__":
    main()
