"""measure toml evaluation, realization and installed generation separately"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import statistics
import subprocess
import time

import tomllib


def expression(source, size, phase, input_path=None, bad=False):
    args = {"source": source, "size": size, "phase": phase, "bad": bad}
    if input_path is not None:
        args["input"] = str(input_path)
    fields = " ".join(key + " = " + json.dumps(value) + ";" for key, value in args.items())
    return "import " + str(Path(__file__).with_suffix(".nix")) + " { " + fields + " }"


def evaluator(source, size, phase, input_path=None, bad=False, rebuild=False):
    operation = ["build", "--no-link"] if phase in ("build", "package") else ["eval"]
    if rebuild:
        operation += ["--rebuild"]
    return ["nix", *operation, "--impure", "--json", "--option", "allow-import-from-derivation", "false",
            "--extra-experimental-features", "pipe-operators", "--expr", expression(source, size, phase, input_path, bad)]


def expected(size, context):
    return {f"item{i}": {"count": i, "precise": 1.2345678901234567, "executable": context,
                         "values": [True, "two", 3], "spelling": 16} for i in range(size)}


def process(output, label, command, child=False, timeout=120):
    target = output / label
    target.mkdir()
    stats = target / "evaluator-stats.json"
    environment = os.environ.copy()
    environment.update(NIX_SHOW_STATS="1", NIX_SHOW_STATS_PATH=str(stats))
    started = time.monotonic()
    timed_out = False
    def expired(_signal, _frame):
        raise TimeoutError()
    signal.signal(signal.SIGALRM, expired)
    with (target / "stdout").open("wb") as stdout, (target / "stderr").open("wb") as stderr:
        p = subprocess.Popen(command, stdout=stdout, stderr=stderr, env=environment, start_new_session=True)
        try:
            signal.setitimer(signal.ITIMER_REAL, timeout)
            _, status, usage = os.wait4(p.pid, 0)
        except TimeoutError:
            timed_out = True
            os.killpg(p.pid, signal.SIGKILL)
            _, status, usage = os.wait4(p.pid, 0)
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)
        p.returncode = os.waitstatus_to_exitcode(status)
    payload = (target / "stdout").read_bytes()
    record = {"command": command, "exit": p.returncode, "wall_seconds": time.monotonic()-started,
              "peak_rss_kib": usage.ru_maxrss, "timed_out": timed_out,
              "process_released": not Path(f"/proc/{p.pid}").exists(),
              "stdout_sha256": hashlib.sha256(payload).hexdigest(),
              "child_evaluators": int(child and stats.exists()), "child_stats_expected": child,
              "evaluator_stats": str(stats) if stats.exists() else None}
    (target / "record.json").write_text(json.dumps(record, indent=2)+"\n")
    return record, payload, target


def closure(output, name, path):
    record, payload, _ = process(output, name, ["nix", "path-info", "--json", "--recursive", path])
    assert record["exit"] == 0
    return {key: value["narSize"] for key, value in json.loads(payload).items()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--primary", action="store_true")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    sources = {"baseline": args.baseline, "candidate": args.candidate}
    records = []
    def run(label, command, child=False, **options):
        record, payload, target = process(args.output, label, command, child, **options)
        records.append(record)
        count = sum(1+r["child_evaluators"] for r in records if r.get("workload", True))
        (args.output / "accounting.json").write_text(json.dumps({"launch_units": count, "records": records}, indent=2)+"\n")
        assert count <= 144
        assert record["process_released"]
        return record, payload, target

    identities = {}
    packages = {}
    for side, source in sources.items():
        r, data, _ = run(side+"-identity", evaluator(source, 4, "identity"))
        assert r["exit"] == 0
        identities[side] = json.loads(data)
        r, data, _ = run(side+"-package", evaluator(source, 4, "package"))
        assert r["exit"] == 0
        packages[side] = json.loads(data)[0]["outputs"]["out"]
    assert identities["baseline"] == identities["candidate"]
    context = identities["baseline"]["context"]
    inputs = {}
    for size in (4, 16, 64):
        r, data, _ = run(f"input-{size}", evaluator(args.baseline, size, "input"))
        assert r["exit"] == 0
        inputs[size] = args.output / f"input-{size}.json"
        inputs[size].write_bytes(data)
    setup = {"identities": identities, "packages": packages}
    (args.output / "setup.json").write_text(json.dumps(setup, indent=2)+"\n")

    def sample(side, size, phase, label, rebuild=False):
        output_file = args.output / (label+".toml")
        command = ([packages[side]+"/bin/lexicon-toml", "generate", str(inputs[size]), str(output_file)]
                   if phase == "cli" else evaluator(sources[side], size, phase, inputs[size], rebuild=rebuild))
        r, data, target = run(label, command, child=phase == "cli" and side == "candidate")
        assert r["exit"] == 0 and not r["timed_out"], target
        if phase == "cli":
            assert r["child_evaluators"] == int(side == "candidate"), target
            text = output_file.read_bytes()
        elif phase == "build":
            text = Path(json.loads(data)[0]["outputs"]["out"]).read_bytes()
        elif phase == "pure":
            result = json.loads(data)
            assert result["context"] == result["expectedContext"] and result["context"], target
            assert len(result["literals"]) == size, target
            text = result["text"].encode()
        else:
            result = json.loads(data)
            assert result["path"].startswith("/nix/store/") and len(result["context"]) == 1, target
            assert next(iter(result["context"].values())) == {"outputs": ["out"]}, target
            return r
        (target / "rendered.toml").write_bytes(text)
        assert tomllib.loads(text.decode()) == expected(size, context), target
        return r

    if not args.primary:
        for side, source in sources.items():
            sample(side, 4, "evaluation", side+"-valid")
            r, _, _ = run(side+"-invalid", evaluator(source, 4, "evaluation", bad=True))
            assert r["exit"] != 0 and not r["timed_out"]
            r, _, _ = run(side+"-opaque", evaluator(source, 4, "opacity"))
            assert r["exit"] == 0
            sample(side, 4, "cli", side+"-cli")
        sample("candidate", 4, "pure", "candidate-pure")
        r, _, _ = run("missing", evaluator("path:/does-not-exist", 4, "evaluation"))
        assert r["exit"] != 0
        r, _, _ = run("timeout", evaluator(args.baseline, 64, "evaluation"), timeout=0.001)
        assert r["timed_out"]
        (args.output / "controls-passed").write_text("passed\n")
        return

    comparisons = []
    for phase in ("evaluation", "build", "cli"):
        for size in (4, 16, 64):
            for side in sources:
                sample(side, size, phase, f"{phase}-{size}-warm-{side}")
            samples = {side: [] for side in sources}
            for index, order in enumerate((("baseline", "candidate"), ("candidate", "baseline"), ("baseline", "candidate"))):
                for side in order:
                    samples[side].append(sample(side, size, phase, f"{phase}-{size}-{index}-{side}", rebuild=phase == "build"))
            medians = {side: {metric: statistics.median(r[metric] for r in rows) for metric in ("wall_seconds", "peak_rss_kib")}
                       for side, rows in samples.items()}
            passed = (medians["candidate"]["wall_seconds"] <= medians["baseline"]["wall_seconds"]*1.35+0.03
                      and medians["candidate"]["peak_rss_kib"] <= medians["baseline"]["peak_rss_kib"]*1.25+8192)
            comparisons.append({"phase": phase, "size": size, "medians": medians, "passed": passed})
            (args.output / "comparisons.json").write_text(json.dumps(comparisons, indent=2)+"\n")
            if not passed:
                raise SystemExit("TOML comparison exceeded its fixed bound")
    for size in (4, 16, 64):
        for index in ("warm", 0, 1, 2):
            sample("candidate", size, "pure", f"pure-{size}-{index}")
    closures = {side: closure(args.output, side+"-closure", path) for side, path in packages.items()}
    common = closures["baseline"].keys() & closures["candidate"].keys()
    delta = {"total_bytes": {side: sum(paths.values()) for side, paths in closures.items()},
             "shared_bytes": sum(closures["baseline"][p] for p in common),
             "exclusive_bytes": {side: sum(size for path, size in paths.items() if path not in common) for side, paths in closures.items()},
             "paths": closures}
    (args.output / "closures.json").write_text(json.dumps(delta, indent=2)+"\n")
    (args.output / "primary-passed").write_text("passed\n")


if __name__ == "__main__":
    main()
