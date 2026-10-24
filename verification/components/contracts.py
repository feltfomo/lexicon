"""check component callbacks, demand and original exceptions with a real evaluator"""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import time


def terminal_expectations():
    expected = {
        "dispatch.validShape": "terminal",
        "dispatch.validShapeSentinel": "terminal",
        "dispatch.executorRecovery": [
            "terminal/executor"
        ],
        "dispatch.indexRecovery": [
            "recovered-index"
        ],
        "dispatch.indexShapeRecovery": [
            "host:/srv/alice/.config/terminal"
        ],
        "dispatch.shapeRecovery": "terminal",
        "dispatch.compileShapeRecovery": "/external/terminal",
        "dispatch.capabilityRecovery": "terminal/executor",
        "dispatch.materializerRecovery": "/external/terminal",
        "dispatch.artifactRecovery": "/external/terminal",
        "dispatch.externalRecovery": {
            "recovered": "external"
        },
        "groups.themeWithin": [
            {
                "diagnostics": [
                    {
                        "code": "program/theme-registration-duplicate",
                        "message": "has duplicate registration id one",
                        "primary": {
                            "label": "theme.caelestia.a"
                        },
                        "severity": "error"
                    },
                    {
                        "code": "program/theme-registration-duplicate",
                        "message": "has duplicate registration id two",
                        "primary": {
                            "label": "theme.caelestia.a"
                        },
                        "severity": "error"
                    }
                ],
                "fallbackLength": 0,
                "text": "program: 2 declaration error(s)\n  - [program/theme-registration-duplicate] theme.caelestia.a: has duplicate registration id one\n  - [program/theme-registration-duplicate] theme.caelestia.a: has duplicate registration id two"
            }
        ],
        "groups.matugenWithin": [
            ".config/matugen/config.toml"
        ],
        "groups.themeRecovery": [
            {
                "diagnostics": [
                    {
                        "code": "program/theme-registration-duplicate",
                        "message": "has duplicate registration id a",
                        "primary": {
                            "label": "theme.caelestia.a"
                        },
                        "severity": "error"
                    }
                ],
                "fallbackLength": 0,
                "text": "program: 1 declaration error(s)\n  - [program/theme-registration-duplicate] theme.caelestia.a: has duplicate registration id a"
            },
            {
                "diagnostics": [
                    {
                        "code": "program/theme-native-unsupported",
                        "message": "cannot use native registration fields: z",
                        "primary": {
                            "label": "theme.caelestia.z"
                        },
                        "severity": "error"
                    }
                ],
                "fallbackLength": 0,
                "text": "program: 1 declaration error(s)\n  - [program/theme-native-unsupported] theme.caelestia.z: cannot use native registration fields: z"
            }
        ],
        "groups.themeSuccessThenRecovery": [
            ".config/caelestia/templates/a-palette.tmpl",
            ".config/caelestia/theme-hooks/a",
            "program: 1 declaration error(s)\n  - [program/theme-native-unsupported] theme.caelestia.z: cannot use native registration fields: z"
        ],
        "groups.themeSuccess": [
            ".config/caelestia/templates/a-palette.tmpl",
            ".config/caelestia/theme-hooks/a"
        ],
        "groups.matugenRecovery": [
            ".config/matugen/config.toml",
            ".config/matugen/config.toml"
        ],
        "groups.matugenSuccess": [
            ".config/matugen/config.toml",
            ".config/matugen/config.toml"
        ],
        "groups.matugenNativeOpaque": [
            ".config/matugen/config.toml",
            ".config/matugen/config.toml"
        ]
    }
    exceptions = {
        "themeWithin": "program: 2 declaration error(s)\n         - [program/theme-registration-duplicate] theme.caelestia.a: has duplicate registration id one\n         - [program/theme-registration-duplicate] theme.caelestia.a: has duplicate registration id two\n",
        "matugenWithin": "program: 2 declaration error(s)\n         - [program/theme-registration-duplicate] theme.dms: has duplicate registration id one for a (alice)\n         - [program/theme-registration-duplicate] theme.dms: has duplicate registration id two for a (alice)\n",
        "themeTwo": "program: 1 declaration error(s)\n         - [program/theme-registration-duplicate] theme.caelestia.a: has duplicate registration id a\n",
        "themePoison": "program: 1 declaration error(s)\n         - [program/theme-registration-duplicate] theme.caelestia.a: has duplicate registration id a\n",
        "themeSuccessThenFailure": "program: 1 declaration error(s)\n         - [program/theme-native-unsupported] theme.caelestia.z: cannot use native registration fields: z\n",
        "matugenTwo": "program: 1 declaration error(s)\n         - [program/theme-registration-duplicate] theme.dms: has duplicate registration id duplicate for a (alice)\n",
        "matugenPoison": "program: 1 declaration error(s)\n         - [program/theme-registration-duplicate] theme.dms: has duplicate registration id duplicate for a (alice)\n",
        "matugenSuccessThenFailure": "program: 1 declaration error(s)\n         - [program/theme-registration-duplicate] theme.dms: has duplicate registration id duplicate for z (alice)\n",
        "matugenNativeAfterDuplicate": "program: 1 declaration error(s)\n         - [program/theme-registration-duplicate] theme.dms: has duplicate registration id duplicate for a (alice)\n",
        "themeSuccessPoison": "later theme native forced\n"
    }
    events = {
        "dispatch.validShape": [],
        "dispatch.validShapeSentinel": [],
        "dispatch.executorRecovery": [
            "fail"
        ],
        "dispatch.indexRecovery": [
            "fail"
        ],
        "dispatch.indexShapeRecovery": [
            "fail"
        ],
        "dispatch.shapeRecovery": [
            "fail"
        ],
        "dispatch.compileShapeRecovery": [
            "provider",
            "fail"
        ],
        "dispatch.capabilityRecovery": [
            "failOne"
        ],
        "dispatch.materializerRecovery": [
            "failOne"
        ],
        "dispatch.artifactRecovery": [
            "fail"
        ],
        "dispatch.externalRecovery": [
            "failOne"
        ],
        "groups.themeWithin": [
            "checked"
        ],
        "groups.matugenWithin": [
            "finish"
        ],
        "groups.themeRecovery": [
            "checked",
            "checked"
        ],
        "groups.themeSuccessThenRecovery": [
            "checked"
        ],
        "groups.themeSuccess": [],
        "groups.matugenRecovery": [
            "finish",
            "finish"
        ],
        "groups.matugenSuccess": [
            "finish",
            "finish"
        ],
        "groups.matugenNativeOpaque": [
            "finish",
            "finish"
        ],
        "exceptions.themeWithin": [],
        "exceptions.matugenWithin": [
            "finish"
        ],
        "exceptions.themeTwo": [],
        "exceptions.themePoison": [],
        "exceptions.themeSuccessThenFailure": [],
        "exceptions.matugenTwo": [
            "finish"
        ],
        "exceptions.matugenPoison": [
            "finish"
        ],
        "exceptions.matugenSuccessThenFailure": [
            "finish",
            "finish"
        ],
        "exceptions.matugenNativeAfterDuplicate": [
            "finish"
        ],
        "exceptions.themeSuccessPoison": []
    }
    return expected, exceptions, events


def main():
    parser = argparse.ArgumentParser()
    inputs = parser.add_mutually_exclusive_group(required=True)
    inputs.add_argument("--source")
    inputs.add_argument("--setup", type=Path)
    parser.add_argument("--family", choices=["ownerships", "compiler", "resources", "terminals"], default="ownerships")
    parser.add_argument("--baseline", action="store_true")
    parser.add_argument("--reference", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    if args.source:
        fixture = Path(__file__).resolve().parents[2] / ("tests/declarations/observations.nix" if args.family == "compiler" else "tests/ownerships/observations.nix")
        setup = ('let p = builtins.getFlake ' + json.dumps(args.source) + '; lib = p.inputs.nixpkgs.lib; '
                 'axiom = p.inputs.axiom.lib.axiom { inherit lib; }; in import ' + str(fixture)
                 + ' { inherit lib axiom; ownerships = p.lib.ownerships; }')
        if args.family == "compiler":
            setup = ('let p = builtins.getFlake ' + json.dumps(args.source) + '; lib = p.inputs.nixpkgs.lib; '
                     'axiom = p.inputs.axiom.lib.axiom { inherit lib; }; deps = import (p.outPath + "/src/dependencies.nix") '
                     '{ inherit lib axiom; krisisSource = p.inputs.krisis; }; compiler = import (p.outPath + "/src/declarations") '
                     '{ inherit lib axiom; inherit (deps) krisis; }; in import ' + str(fixture)
                     + ' { inherit lib axiom compiler; }')
        if args.family == "resources":
            fixture = Path(__file__).resolve().parents[2] / "tests/furnish/observations.nix"
            setup = ('let p = builtins.getFlake ' + json.dumps(args.source) + '; lib = p.inputs.nixpkgs.lib; '
                     'axiom = p.inputs.axiom.lib.axiom { inherit lib; }; deps = import (p.outPath + "/src/dependencies.nix") '
                     '{ inherit lib axiom; krisisSource = p.inputs.krisis; }; in import ' + str(fixture)
                     + ' { inherit lib axiom; inherit (deps) krisis; pkgs = p.inputs.nixpkgs.legacyPackages.${builtins.currentSystem}; lexicon = p; }')
        if args.family == "terminals":
            fixture = Path(__file__).resolve().parents[2] / "tests/furnish/terminals.nix"
            setup = ('let p = builtins.getFlake ' + json.dumps(args.source) + '; lib = p.inputs.nixpkgs.lib; '
                     'axiom = p.inputs.axiom.lib.axiom { inherit lib; }; in import ' + str(fixture)
                     + ' { inherit lib axiom; lexicon = p; krisisSource = p.inputs.krisis; source = p.outPath; }')
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
    if args.family == "compiler":
        entries = [{"id": i + 1, "defaulted": 7, "tag": i + 10,
                    "origin": ["sample", "entries", i + 1], "prepared": i} for i in range(2)]
        expected = {cell: {name: {"entries": entries, "marker": i, "root": True}
                          for i, name in enumerate(["first", "second"])} for cell in ["static", "dynamic"]}
        callbacks = {cell: {"parse 0": 2, "parse 1": 2, "normalize": 4, "metadata": 7,
                            "preparation root": 1, "preparation 0": 1 if cell == "static" else 2,
                            "preparation 1": 1 if cell == "static" else 2, "lowering": 2,
                            "callback": 0 if cell == "static" else 2} for cell in expected}
        exception_markers = {name: f"compiler {name} exception" for name in
                             ["parse", "normalize", "preparation", "lowering", "callback"]}
    if args.family == "resources":
        expected = {
            "inventory": {name: [{"destination": ".opaque", "principal": user},
                                 {"destination": ".inventory/root.nix", "principal": user}]
                          for name, user in [("first", "alice"), ("second", "bob")]},
            "materialization": {name: "/nix/store/" for name in ("first", "second")},
            "poison": True,
        }
        callbacks = {"inventory": {"inventory": 1}, "materialization": {"materialize": 1}}
        exception_markers = {"provider": "resource effects provider exception",
                             "materializer": "resource effects materializer exception"}
    if args.family == "terminals":
        expected, exception_texts, terminal_events = terminal_expectations()
        callbacks = {}
        exception_markers = {name: value for name, value in exception_texts.items()}
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
        events = re.findall(r"^trace: " + ({"compiler": "compiler", "resources": "resource-effects", "terminals": "terminal"}.get(args.family, "fleet")) + r" (.*)$", stderr, re.MULTILINE)
        if cell in expected:
            try:
                decoded = json.loads(stdout)
                if args.family == "resources" and cell == "materialization":
                    admitted = exit_code == 0 and decoded["first"] == decoded["second"] and decoded["first"].startswith("/nix/store/")
                else:
                    admitted = exit_code == 0 and decoded == expected[cell]
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
                if args.family == "compiler" and args.reference:
                    reference_events = re.findall(r"^trace: compiler (.*)$", (args.reference / (cell + ".stderr")).read_text(), re.MULTILINE)
                    admitted = admitted and events == reference_events
        else:
            marker = exception_markers[cell.split(".")[1]]
            terminal = stderr.rsplit("error: ", 1)[-1]
            admitted = exit_code is not None and exit_code != 0 and marker in terminal and "premature" not in terminal
            if args.family == "terminals":
                admitted = admitted and terminal == exception_texts[cell.split(".", 1)[1]]
            if args.reference:
                reference = (args.reference / (cell + ".stderr")).read_text().rsplit("error: ", 1)[-1]
                admitted = admitted and terminal == reference
            if args.family == "compiler" and cell in ["exceptions.callback", "exceptions.preparation", "exceptions.lowering"]:
                context = {"exceptions.callback": "lexicon callback at $.sample",
                           "exceptions.preparation": "lexicon preparation at $.sample",
                           "exceptions.lowering": "lexicon lowering block sample"}[cell]
                admitted = admitted and context in stderr
            if args.family == "resources":
                context = {"exceptions.provider": "furnish: while selecting applicable declarations",
                           "exceptions.materializer": "furnish: while materializing declaration 'resource' with executor 'test/selected'"}[cell]
                admitted = admitted and context in stderr
            if cell == "exceptions.selector":
                admitted = admitted and "while evaluating 'when' predicate" in stderr
            if cell == "exceptions.import":
                admitted = admitted and "while importing ownership units" in stderr
        if args.family == "terminals":
            admitted = admitted and events == terminal_events[cell]
        record = {"cell": cell, "command": command, "exit": exit_code, "wall_seconds": elapsed,
                  "events": events, "timed_out": timed_out, "admitted": bool(admitted) and not timed_out}
        records.append(record)
        (args.output / "records.json").write_text(json.dumps(records, indent=2) + "\n")
        if not admitted:
            print("\n".join(stderr.splitlines()[-30:]), file=sys.stderr)
            raise RuntimeError(f"{args.family} contract failed {cell}; see {args.output}")
    print(json.dumps({"checks": len(records), "all_admitted": True}))


if __name__ == "__main__":
    main()
