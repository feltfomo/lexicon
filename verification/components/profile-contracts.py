#!/usr/bin/env python3
"""assert evaluator instrumentation records and map their source positions to exact bytes"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys


# record grammar and flush behavior were read from the 2.34.8 evaluator source, so another version is unsupported
SUPPORTED_EVALUATOR = "nix (Nix) 2.34.8"
FRAME = re.compile(r"(?P<origin>.+?):(?P<line>[0-9]+)(?::(?P<column>[0-9]+))?(?::(?P<label>.+))?")
STORE_ENTRY = re.compile(r"[0-9a-z]{32}-[^/]+")
STATISTIC_COUNTS = ("nrFunctionCalls", "nrPrimOpCalls", "nrThunks", "nrLookups", "nrAvoided", "nrOpUpdates")


class RecordError(Exception):
    def __init__(self, kind, message):
        super().__init__(message)
        self.kind = kind


def frame(text):
    match = FRAME.fullmatch(text)
    if match is None:
        return {"text": text, "label": text, "provenance": "unpositioned"}
    column = match["column"]
    label = match["label"]
    # a primop prints its position only when the call site resolved, while lambda and functor
    # frames silently fall back to the definition or functor attribute when it didn't
    if label is not None and label.startswith("primop "):
        provenance = "call-site"
    elif label == "functor":
        provenance = "call-site-or-functor-attribute"
    else:
        provenance = "call-site-or-lambda-definition"
    return {"text": text, "origin": match["origin"], "line": int(match["line"]),
            "column": int(column) if column else None, "label": label, "provenance": provenance}


def natural(value, minimum):
    return isinstance(value, int) and not isinstance(value, bool) and value >= minimum


def canonical_position(match):
    """2.34.8 prints line and column as plain unsigned integers and omits a zero column"""
    if match is None:
        return True
    return bool(re.fullmatch(r"0|[1-9][0-9]*", match["line"])
                and (match["column"] is None or re.fullmatch(r"[1-9][0-9]*", match["column"])))


def function_entry(entry):
    """one functions entry exactly as the 2.34.8 writer emits it"""
    if not isinstance(entry, dict) or not natural(entry.get("count"), 1):
        return False
    if "name" not in entry or not (entry["name"] is None or isinstance(entry["name"], str)):
        return False
    # line and column come together only for a positioned lambda, and file only for a path origin
    extra = set(entry) - {"name", "count"}
    if extra not in (set(), {"line", "column"}, {"file", "line", "column"}):
        return False
    return not extra or (natural(entry["line"], 1) and natural(entry["column"], 0)
                         and ("file" not in entry or (isinstance(entry["file"], str) and entry["file"] != "")))


def folded_stacks(data):
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise RecordError("malformed", f"profile is not utf-8 {error}") from None
    if not text:
        raise RecordError("absent", "profile contains no samples")
    if not text.endswith("\n"):
        raise RecordError("malformed", "profile ends inside a line")
    stacks = {}
    lines = text[:-1].split("\n")
    for number, line in enumerate(lines, 1):
        frames, _, count = line.rpartition(" ")
        if not re.fullmatch(r"[1-9][0-9]*", count) or not frames:
            raise RecordError("malformed", f"profile line {number} lacks a positive sample count")
        stack = tuple(frames.split(";"))
        if not all(stack):
            raise RecordError("malformed", f"profile line {number} has an empty frame")
        for text in stack:
            if not canonical_position(FRAME.fullmatch(text)):
                raise RecordError("malformed", f"profile line {number} has an invalid position {text!r}")
        # the evaluator flushes and clears its sample map every two seconds, so a stack can recur
        stacks[stack] = stacks.get(stack, 0) + int(count)
    return stacks, len(lines)


def folded_summary(data):
    stacks, lines = folded_stacks(data)
    frames = {text for stack in stacks for text in stack}
    positioned = sum(1 for text in frames if "origin" in frame(text))
    return {"lines": lines, "stacks": len(stacks), "samples": sum(stacks.values()),
            "repeated_stack_lines": lines - len(stacks), "max_depth": max(map(len, stacks)),
            "frames": len(frames), "positioned_frames": positioned, "unpositioned_frames": len(frames) - positioned}


def statistics(data):
    try:
        value = json.loads(data)
    except (UnicodeDecodeError, ValueError) as error:
        raise RecordError("malformed", f"statistics are not json {error}") from None
    if not isinstance(value, dict):
        raise RecordError("malformed", "statistics are not an object")
    if "functions" not in value or "primops" not in value:
        raise RecordError("unsupported", "statistics lack call counts")
    # 2.34.8 assigns the attribute list through a copy, so the emitted field is always null
    if value.get("attributes", "missing") is not None:
        raise RecordError("unsupported", "attribute selections differ from the qualified evaluator")
    if not all(natural(value.get(name), 0) for name in STATISTIC_COUNTS):
        raise RecordError("malformed", "statistics lack evaluator counters")
    primops = value["primops"]
    if not isinstance(primops, dict) or not all(isinstance(k, str) and natural(v, 1) for k, v in primops.items()):
        raise RecordError("malformed", "primop counts are malformed")
    functions = value["functions"]
    for entry in functions if isinstance(functions, list) else [None]:
        if not function_entry(entry):
            raise RecordError("malformed", f"function count entry is malformed {entry!r}")
    # both totals and their per-site maps are incremented together when calls are counted
    if sum(entry["count"] for entry in functions) != value["nrFunctionCalls"]:
        raise RecordError("malformed", "function counts don't sum to the evaluator's call total")
    if sum(primops.values()) != value["nrPrimOpCalls"]:
        raise RecordError("malformed", "primop counts don't sum to the evaluator's primop total")
    if not functions:
        raise RecordError("absent", "statistics count no function applications")
    return value


def statistics_summary(data):
    value = statistics(data)
    gc = value.get("gc", {})
    return {"function_sites": len(value["functions"]), "positioned_function_sites": sum("line" in e for e in value["functions"]),
            "primops": len(value["primops"]), **{name: value[name] for name in STATISTIC_COUNTS},
            "cpu_seconds": value.get("cpuTime"), "values": value.get("values", {}).get("number"),
            "envs": value.get("envs", {}).get("number"), "sets": value.get("sets", {}).get("number"),
            "gc_heap_bytes": gc.get("heapSize"), "gc_total_bytes": gc.get("totalBytes"), "gc_cycles": gc.get("cycles")}


SUMMARIES = {"flamegraph": folded_summary, "counts": statistics_summary}


def capture(mode, path, marker_ns, evaluator):
    path = Path(path)
    result = {"mode": mode, "record": str(path), "launch_marker_ns": marker_ns, "present": False,
              "valid": False, "failure": None, "error": None}
    try:
        if mode not in SUMMARIES:
            raise RecordError("unsupported", f"instrumentation mode {mode}")
        if evaluator != SUPPORTED_EVALUATOR:
            raise RecordError("unsupported", f"evaluator {evaluator}")
        try:
            metadata = path.lstat()
        except FileNotFoundError:
            raise RecordError("absent", "the evaluator wrote no instrumentation record") from None
        result["present"] = True
        if not stat.S_ISREG(metadata.st_mode):
            raise RecordError("malformed", "instrumentation record isn't a regular file")
        if metadata.st_uid != os.getuid() or metadata.st_mtime_ns < marker_ns:
            raise RecordError("stale", "instrumentation record predates this evaluator")
        data = path.read_bytes()
        result.update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest(), mtime_ns=metadata.st_mtime_ns)
        result["summary"] = SUMMARIES[mode](data)
        result["valid"] = True
    except RecordError as error:
        result.update(failure=error.kind, error=str(error))
    return result


def git_blob(repository, revision, relative):
    completed = subprocess.run(["git", "-C", repository, "cat-file", "blob", f"{revision}:{relative}"], capture_output=True)
    return completed.stdout if completed.returncode == 0 else None


def root_bytes(root, relative):
    if "git" in root:
        return git_blob(root["git"], root["revision"], relative)
    path = Path(root["tree"]) / relative
    return path.read_bytes() if path.is_file() else None


def located_root(root, relative, displayed):
    content = root_bytes(root, relative)
    expected = root.get("manifest", {}).get(relative, {}).get("sha256")
    if content is None:
        return None
    if (displayed is not None and content != displayed) or (expected is not None and hashlib.sha256(content).hexdigest() != expected):
        return False
    return content


def locate(display, roots, store):
    def prefix(root):
        return root.get("tree", root.get("git"))
    direct = sorted((root for root in roots if display.startswith(prefix(root) + "/")), key=lambda root: len(prefix(root)))
    # substituted and fetched inputs display as their locked reference followed by the path inside the input
    mounted = re.fullmatch(r"«(?P<input>[^»]+)»/(?P<relative>.+)", display)
    if mounted:
        named = [root for root in roots if ("revision" in root and root["revision"] in mounted["input"])
                 or ("tree" in root and re.search("(^|:)" + re.escape(root["tree"]) + r"(\?|$)", mounted["input"]))]
        if len(named) != 1:
            return {"status": "unbound" if not named else "ambiguous", "input": mounted["input"]}
        content = located_root(named[0], mounted["relative"], None)
        if content is None or content is False:
            return {"status": "stale" if content is False else "unbound", "root": named[0]["name"], "relative": mounted["relative"]}
        return {"status": "mapped", "root": named[0]["name"], "relative": mounted["relative"], "input": mounted["input"],
                "display_sha256": None, "bytes": content}
    if direct:
        # nested roots resolve to the innermost owner
        candidates = [(direct[-1], display[len(prefix(direct[-1])) + 1:])]
    else:
        entries = store.rstrip("/") + "/"
        if not display.startswith(entries) or "/" not in display[len(entries):]:
            return {"status": "unmapped-origin"}
        entry, _, relative = display[len(entries):].partition("/")
        if not STORE_ENTRY.fullmatch(entry):
            return {"status": "unmapped-origin"}
        candidates = [(root, relative) for root in roots]
    try:
        displayed = Path(display).read_bytes()
    except OSError:
        return {"status": "unreadable"}
    located = {"display_sha256": hashlib.sha256(displayed).hexdigest()}
    owners = []
    for root, relative in candidates:
        content = located_root(root, relative, displayed)
        if content is False and direct:
            return {**located, "status": "stale", "root": root["name"], "relative": relative}
        if content is not None and content is not False:
            owners.append((root["name"], relative))
    if len(owners) > 1:
        return {**located, "status": "ambiguous", "owners": owners}
    if not owners:
        return {**located, "status": "unbound", "bytes": displayed}
    return {**located, "status": "mapped", "root": owners[0][0], "relative": owners[0][1], "bytes": displayed}


def indexed(located):
    """split one origin's bytes once, keeping its hash, lines and line start offsets for every position"""
    content = located.pop("bytes", None)
    if content is None:
        return located, None
    lines = content.split(b"\n")
    offsets = [0]
    for text in lines[:-1]:
        offsets.append(offsets[-1] + len(text) + 1)
    return located, (hashlib.sha256(content).hexdigest(), tuple(lines), tuple(offsets))


def source_bytes(located, index, line, column):
    located = dict(located)
    if index is None or line is None:
        return located
    digest, lines, offsets = index
    # classification binds line ranges to these exact bytes, never to a path alone
    located["content_sha256"] = digest
    if line == 0:
        return {**located, "status": "position-unresolved"}
    if not 1 <= line <= len(lines):
        return {**located, "status": "position-outside-file"}
    text = lines[line - 1]
    # the evaluator's column counts bytes from one, and zero means it recorded none
    start = column - 1 if column else 0
    if start > len(text):
        return {**located, "status": "position-outside-line", "line_text": text.decode("utf-8", "replace")}
    result = {**located, "byte_offset": offsets[line - 1] + start, "line_text": text.decode("utf-8", "replace"),
              "excerpt": text[start:start + 160].decode("utf-8", "replace")}
    if not column:
        result["column_recorded"] = False
    return result


def map_record(observation, roots, store):
    record = json.loads((observation / "record.json").read_text())
    instrumentation = record["instrumentation"]
    if not instrumentation.get("valid"):
        raise RecordError(instrumentation.get("failure") or "absent", "observation has no admitted instrumentation")
    data = Path(instrumentation["record"]).read_bytes()
    if hashlib.sha256(data).hexdigest() != instrumentation["sha256"]:
        raise RecordError("stale", "instrumentation record changed after capture")
    origins = {}
    positions = {}
    def position(origin, line, column):
        key = f"{origin}:{line}" + ("" if column is None else f":{column}")
        if key not in positions:
            if origin not in origins:
                origins[origin] = indexed(locate(origin, roots, store))
            positions[key] = source_bytes(*origins[origin], line, column)
        return key
    if instrumentation["mode"] == "flamegraph":
        stacks, _ = folded_stacks(data)
        frames = sorted({text for stack in stacks for text in stack})
        index = {text: i for i, text in enumerate(frames)}
        parsed = [frame(text) for text in frames]
        for item in parsed:
            if "origin" in item:
                item["position"] = position(item["origin"], item["line"], item["column"])
        result = {"mode": "flamegraph", "frames": parsed,
                  "stacks": [{"frames": [index[text] for text in stack], "samples": count} for stack, count in stacks.items()]}
    else:
        value = statistics(data)
        for entry in value["functions"]:
            entry["provenance"] = "definition"
            if "file" in entry:
                entry["position"] = position(entry["file"], entry.get("line"), entry.get("column"))
        result = {"mode": "counts", "functions": value["functions"], "primops": value["primops"]}
    result["positions"] = positions
    result["statuses"] = {status: sum(1 for p in positions.values() if p["status"] == status)
                          for status in sorted({p["status"] for p in positions.values()})}
    result["record_sha256"] = instrumentation["sha256"]
    return result


def roots_from(path):
    roots = json.loads(Path(path).read_text())["roots"]
    for root in roots:
        if "manifest" in root and isinstance(root["manifest"], str):
            root["manifest"] = json.loads(Path(root["manifest"]).read_text())
    return roots


FAKE_EVALUATOR = """#!{python}
import json, os, signal, sys, time
from pathlib import Path
arguments = sys.argv[1:]
with open(os.environ["PROFILE_QUALIFY_LOG"], "a") as log:
    log.write(json.dumps({{"argv": arguments, "environment": {{k: v for k, v in os.environ.items() if k.startswith("NIX_")}}}}) + "\\n")
if arguments == ["--version"]:
    time.sleep(json.loads(os.environ.get("PROFILE_QUALIFY_SCENARIO", "{{}}")).get("version_sleep", 0))
    print(os.environ.get("PROFILE_QUALIFY_VERSION", {version!r}))
    raise SystemExit(0)
scenario = json.loads(os.environ["PROFILE_QUALIFY_SCENARIO"])
destination = arguments[arguments.index("eval-profile-file") + 1] if "eval-profile-file" in arguments else os.environ.get("NIX_SHOW_STATS_PATH")
if "eval-profile-file" in arguments and not scenario.get("backdate"):
    Path(destination).write_bytes(scenario.get("partial", "").encode())
if scenario.get("orphan"):
    import subprocess
    subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
terminated = []
if scenario.get("on_term") == "ignore":
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
elif scenario.get("on_term") == "unwind":
    signal.signal(signal.SIGTERM, lambda *_: terminated.append(time.monotonic()))
deadline = time.monotonic() + scenario.get("sleep", 0)
while time.monotonic() < deadline and not (terminated and time.monotonic() >= terminated[0] + scenario.get("after_term", 0)):
    time.sleep(0.01)
if terminated:
    if destination and scenario.get("record") is not None:
        Path(destination).write_bytes(scenario["record"].encode())
    sys.stderr.write("error: interrupted by the user\\n")
    raise SystemExit(1)
if destination and scenario.get("record") is not None:
    Path(destination).write_bytes(scenario["record"].encode())
    if scenario.get("backdate"):
        os.utime(destination, ns=(0, 0))
if scenario.get("drift"):
    with open(scenario["drift"], "a") as bound:
        bound.write("# drift\\n")
sys.stdout.write(scenario.get("stdout", ""))
sys.stderr.write(scenario.get("stderr", ""))
raise SystemExit(scenario.get("exit", 0))
"""


def diagnostics_output(size):
    count = 2 * size
    return json.dumps({"component": "praxis-diagnostics", "size": size, "value": {
        "codes": ["praxis/args-shape"] * count, "paths": [[0]] * count,
        "summary": {"total": count, "hasErrors": True, "byCode": {"praxis/args-shape": count},
                    "bySeverity": {"error": count, "warning": 0, "info": 0}}}})


def statistics_fixture(**changes):
    value = {"cpuTime": 0.25, "time": {"cpu": 0.25, "gc": 0.01, "gcFraction": 0.04},
             "envs": {"number": 9, "elements": 12, "bytes": 168}, "nrExprs": 40,
             "list": {"elements": 3, "bytes": 24, "concats": 1}, "values": {"number": 30, "bytes": 480},
             "symbols": {"number": 20, "bytes": 200}, "sets": {"number": 4, "bytes": 96, "elements": 6},
             "sizes": {"Env": 16, "Value": 16, "Bindings": 24, "Attr": 16}, "nrOpUpdates": 0,
             "nrOpUpdateValuesCopied": 0, "nrThunks": 11, "nrAvoided": 2, "nrLookups": 5, "nrPrimOpCalls": 5,
             "nrFunctionCalls": 7, "gc": {"heapSize": 4096, "totalBytes": 8192, "cycles": 1},
             "primops": {"import": 2, "map": 3},
             "functions": [{"name": "check", "file": "/q/fixture/praxis.nix", "line": 10, "column": 12, "count": 4},
                           {"name": None, "line": 1, "column": 1, "count": 3}],
             "attributes": None}
    value.update(changes)
    return json.dumps(value, indent=2) + "\n"


# frame lines from the 2.34.8 flamegraph-profiler functional test plus repeated stacks from separate flushes
UPSTREAM_FRAMES = [
    "«string»:1:22:f", "«string»:1:1", "«string»:1:1:primop head", "«string»:1:9:primop all",
    "«string»:1:47:primop all;«string»:1:31:f", "«string»:1:1:functor;«string»:1:2",
    "«string»:1:1:primop tryEval;«string»:1:19:primop throw", "«string»:1:1:primop derivationStrict:somepackage",
]
FOLDED = "".join(f"{stack} 1\n" for stack in UPSTREAM_FRAMES) + "/q/fixture/workload.nix:107:11:primop import;/q/fixture/praxis.nix:10:12:check 4\n/q/fixture/workload.nix:107:11:primop import;/q/fixture/praxis.nix:10:12:check 2\n"


def qualify(output):
    output.mkdir(parents=True, exist_ok=False)
    observer = Path(__file__).with_name("observe.py")
    fake = output / "fake-bin"
    fake.mkdir()
    (fake / "nix").write_text(FAKE_EVALUATOR.format(python=sys.executable, version=SUPPORTED_EVALUATOR))
    (fake / "nix").chmod(0o755)
    fixture = output / "fixture"
    fixture.mkdir()
    (fixture / "workload.nix").write_text("{ ... }: { }\n")
    (fixture / "praxis.nix").write_text("{ ... }:\nlet\n  check = value: value;\nin\ncheck\n")
    identities = {name: hashlib.sha256((fixture / name).read_bytes()).hexdigest() for name in ("workload.nix", "praxis.nix")}
    log = output / "evaluator-invocations.jsonl"
    results = []

    def observe(name, instrumentation="none", scenario=None, extra=(), environment=None, bind=True):
        target = output / "observations" / name
        command = [sys.executable, str(observer), "--source", "path:/q/source", "--component", "praxis-diagnostics",
                   "--size", "4", "--output", str(target), *(["--instrumentation", instrumentation] if instrumentation else []), *extra]
        if bind:
            command += ["--dispatcher", str(fixture / "workload.nix")] + [f"--bind={n}={d}" for n, d in identities.items()]
        before = log.read_text().count("\n") if log.exists() else 0
        env = {"PATH": str(fake), "PROFILE_QUALIFY_LOG": str(log),
               "PROFILE_QUALIFY_SCENARIO": json.dumps(scenario or {"stdout": diagnostics_output(4)}), **(environment or {})}
        completed = subprocess.run(command, env=env, capture_output=True, text=True)
        invocations = [json.loads(line) for line in log.read_text().splitlines()[before:]] if log.exists() else []
        record = json.loads((target / "record.json").read_text()) if (target / "record.json").exists() else None
        return completed, record, invocations

    def case(name, condition, evidence):
        results.append({"case": name, "passed": bool(condition), "evidence": evidence})

    def rejected(name, instrumentation, scenario, failure, **options):
        completed, record, invocations = observe(name, instrumentation, scenario, **options)
        found = record and record["instrumentation"]
        case(name, completed.returncode == 1 and record and not record["admitted"] and record["exit"] == scenario.get("exit", 0)
             and found["failure"] == failure and not found["valid"] and len(invocations) == 2,
             {"exit": completed.returncode, "instrumentation": found})

    parsed = [frame(text) for stack in UPSTREAM_FRAMES for text in stack.split(";")]
    case("frame-grammar", [item["label"] for item in parsed] == [
        "f", None, "primop head", "primop all", "primop all", "f", "functor", None, "primop tryEval", "primop throw",
        "primop derivationStrict:somepackage"] and all(item.get("origin") == "«string»" and item["line"] == 1 for item in parsed), parsed)
    stacks, lines = folded_stacks(FOLDED.encode())
    case("folded-repeated-flushes", lines == 10 and len(stacks) == 9 and stacks[("/q/fixture/workload.nix:107:11:primop import", "/q/fixture/praxis.nix:10:12:check")] == 6,
         {"lines": lines, "stacks": len(stacks)})
    case("unpositioned-primop-frame", frame("primop head") == {"text": "primop head", "label": "primop head", "provenance": "unpositioned"},
         frame("primop head"))
    case("frame-provenance", [item["provenance"] for item in parsed] == [
        "call-site-or-lambda-definition", "call-site-or-lambda-definition", "call-site", "call-site", "call-site",
        "call-site-or-lambda-definition", "call-site-or-functor-attribute", "call-site-or-lambda-definition", "call-site", "call-site",
        "call-site"], [item["provenance"] for item in parsed])

    completed, record, invocations = observe("ordinary-default-dispatcher", bind=False)
    default = str(observer.with_name("workload.nix"))
    expression = ('import ' + default + ' { source = "path:/q/source"; component = "praxis-diagnostics"; size = 4; bad = false; '
                  'initializeReport = false; outputProjection = "default"; }')
    case("ordinary-command-unchanged", completed.returncode == 0 and record["admitted"]
         and record["command"] == ["nix", "eval", "--impure", "--json", "--option", "allow-import-from-derivation", "false",
                                   "--extra-experimental-features", "pipe-operators", "--expr", expression]
         and record["instrumentation"] == {"mode": "none"} and not any(k in i["environment"] for i in invocations
                                                                         for k in ("NIX_SHOW_STATS", "NIX_COUNT_CALLS")),
         {"record": record, "invocations": invocations})

    # ordinary capture predates instrumentation, so whatever its caller exports still reaches the evaluator
    for name, inherited in (("ordinary-inherited-counting", {"NIX_SHOW_STATS": "1", "NIX_COUNT_CALLS": "1",
                                                             "NIX_SHOW_STATS_PATH": str(output / "elsewhere.json"), "NIX_SHOW_SYMBOLS": "1"}),
                            ("ordinary-inherited-zero", {"NIX_SHOW_STATS": "0", "NIX_COUNT_CALLS": "0"}),
                            ("ordinary-configured-profiler", {"NIX_CONFIG": "eval-profiler = flamegraph\ntrace-function-calls = true"})):
        completed, record, invocations = observe(name, None, bind=False, environment=inherited)
        case(name, completed.returncode == 0 and record["admitted"] and record["command"][:-1] == [
                 "nix", "eval", "--impure", "--json", "--option", "allow-import-from-derivation", "false",
                 "--extra-experimental-features", "pipe-operators", "--expr"]
             and record["instrumentation"] == {"mode": "none"} and len(invocations) == 2
             and all({k: i["environment"].get(k) for k in inherited} == inherited for i in invocations),
             {"exit": completed.returncode, "stderr": completed.stderr[-400:], "invocations": invocations})

    for mode, content in (("flamegraph", FOLDED), ("counts", statistics_fixture())):
        completed, record, invocations = observe(f"{mode}-valid", mode, {"stdout": diagnostics_output(4), "record": content})
        launch = invocations[0] if invocations else {"argv": [], "environment": {}}
        if mode == "flamegraph":
            separated = (launch["argv"][launch["argv"].index("eval-profiler") + 1] == "flamegraph"
                         and launch["argv"][launch["argv"].index("eval-profiler-frequency") + 1] == "1000"
                         and not any(k in launch["environment"] for k in ("NIX_SHOW_STATS", "NIX_COUNT_CALLS", "NIX_SHOW_STATS_PATH")))
        else:
            separated = (launch["argv"][launch["argv"].index("eval-profiler") + 1] == "disabled"
                         and "eval-profile-file" not in launch["argv"] and launch["environment"].get("NIX_SHOW_STATS") == "1"
                         and launch["environment"].get("NIX_COUNT_CALLS") == "1"
                         and launch["environment"].get("NIX_SHOW_STATS_PATH") == record["instrumentation"]["record"])
        case(f"{mode}-captured", completed.returncode == 0 and record["admitted"] and record["instrumentation"]["valid"]
             and separated and len(invocations) == 2 and invocations[1]["argv"] == ["--version"]
             and not any(k in invocations[1]["environment"] for k in ("NIX_SHOW_STATS", "NIX_COUNT_CALLS")),
             {"record": record, "invocations": invocations})

    valid_output = diagnostics_output(4)
    for mode, malformed, unsupported in (
            ("flamegraph", "frames without a count\n", None),
            ("counts", "{not json", statistics_fixture(functions=[], primops={}, nrFunctionCalls=0, nrPrimOpCalls=0, attributes=[]))):
        rejected(f"{mode}-absent", mode, {"stdout": valid_output}, "absent")
        rejected(f"{mode}-stale", mode, {"stdout": valid_output, "record": FOLDED if mode == "flamegraph" else statistics_fixture(), "backdate": True}, "stale")
        rejected(f"{mode}-malformed", mode, {"stdout": valid_output, "record": malformed}, "malformed")
        rejected(f"{mode}-unsupported-evaluator", mode, {"stdout": valid_output, "record": FOLDED if mode == "flamegraph" else statistics_fixture()},
                 "unsupported", environment={"PROFILE_QUALIFY_VERSION": "nix (Nix) 2.35.1"})
        if unsupported:
            rejected(f"{mode}-unsupported-record", mode, {"stdout": valid_output, "record": unsupported}, "unsupported")
    rejected("flamegraph-empty", "flamegraph", {"stdout": valid_output, "record": ""}, "absent")
    rejected("flamegraph-partial-line", "flamegraph", {"stdout": valid_output, "record": "«string»:1:1 1"}, "malformed")
    rejected("counts-missing-call-counts", "counts", {"stdout": valid_output, "record": json.dumps({"cpuTime": 0.1, "attributes": None})}, "unsupported")
    rejected("counts-total-mismatch", "counts", {"stdout": valid_output, "record": statistics_fixture(nrFunctionCalls=8)}, "malformed")
    rejected("counts-no-applications", "counts", {"stdout": valid_output, "record": statistics_fixture(functions=[], nrFunctionCalls=0)}, "absent")

    terminal = "error: [praxis/commands] praxis: commands must be an attribute set\n"
    for mode, content in (("none", None), ("flamegraph", FOLDED), ("counts", statistics_fixture())):
        completed, record, invocations = observe(f"{mode}-malformed-fixture", mode, {"stderr": terminal, "exit": 1, "record": content}, extra=["--bad"])
        stderr = (output / "observations" / f"{mode}-malformed-fixture" / "stderr").read_text()
        case(f"{mode}-malformed-fixture-rejected", completed.returncode == 1 and record and not record["admitted"] and record["exit"] == 1
             and record["output_bytes"] == 0 and stderr.endswith(terminal) and record["validation_error"] is None
             and (mode == "none" or record["instrumentation"]["valid"]) and "bad = true;" in record["command"][-1],
             {"record": record})

    completed, record, invocations = observe("timeout-flamegraph", "flamegraph", {"stdout": valid_output, "sleep": 30}, extra=["--timeout-seconds", "0.5"])
    case("timeout-released", completed.returncode == 1 and record["timed_out"] and record["process_released"] and not record["admitted"]
         and record["instrumentation"]["failure"] == "absent", {"record": record})
    # a deferring evaluator must still stop at the limit, keeping whatever it flushed before and nothing after
    partial = "/q/fixture/workload.nix:107:11:primop import 3\n"
    for mode in ("none", "flamegraph", "counts"):
        for behavior in ("ignore", "unwind"):
            name = f"deadline-{mode}-{behavior}"
            completed, record, invocations = observe(name, mode, {
                "stdout": valid_output, "sleep": 30, "on_term": behavior, "after_term": 0.3, "partial": partial,
                "record": FOLDED if mode == "flamegraph" else statistics_fixture()}, extra=["--timeout-seconds", "0.5"])
            stderr = (output / "observations" / name / "stderr").read_text()
            found = record["instrumentation"]
            retained = {"none": found == {"mode": "none"},
                        "flamegraph": found.get("valid") and found["summary"]["samples"] == 3,
                        "counts": found.get("failure") == "absent"}[mode]
            case(name, completed.returncode == 1 and record["timed_out"] and record["exit"] == -9 and record["process_released"]
                 and not record["admitted"] and 0.5 <= record["wall_seconds"] < 0.75 and "interrupted" not in stderr
                 and len(invocations) == 2 and retained, {"record": record})

    drifted = output / "drift"
    drifted.mkdir()
    for name in identities:
        (drifted / name).write_bytes((fixture / name).read_bytes())
    completed, record, invocations = observe("binding-drift", "flamegraph", {"stdout": valid_output, "record": FOLDED, "drift": str(drifted / "praxis.nix")},
                                             bind=False, extra=["--dispatcher", str(drifted / "workload.nix")] + [f"--bind={n}={d}" for n, d in identities.items()])
    case("binding-drift-rejected", completed.returncode == 1 and not record["admitted"] and not record["dispatcher"]["unchanged_after_release"]
         and record["instrumentation"]["valid"], {"record": record})

    refusals = {
        "render-instrumentation": dict(instrumentation="flamegraph", extra=["--phase", "render"]),
        "inherited-counting": dict(instrumentation="flamegraph", environment={"NIX_SHOW_STATS": "1"}),
        "inherited-zero": dict(instrumentation="flamegraph", environment={"NIX_COUNT_CALLS": "0"}),
        "inherited-statistics-path": dict(instrumentation="counts", environment={"NIX_SHOW_STATS_PATH": "/q/elsewhere"}),
        "configured-profiler": dict(instrumentation="counts", environment={"NIX_CONFIG": "eval-profiler = flamegraph"}),
        "configured-tracing": dict(instrumentation="flamegraph", environment={"NIX_CONFIG": "trace-function-calls = true"}),
        "unbound-dispatcher": dict(bind=False, extra=["--dispatcher", str(fixture / "workload.nix")]),
        "relative-dispatcher": dict(bind=False, extra=["--dispatcher", "workload.nix", f"--bind=workload.nix={identities['workload.nix']}"]),
        "stale-binding": dict(bind=False, extra=["--dispatcher", str(fixture / "workload.nix"), f"--bind=workload.nix={identities['workload.nix']}", "--bind=praxis.nix=" + "0" * 64]),
        "malformed-binding": dict(bind=False, extra=["--dispatcher", str(fixture / "workload.nix"), "--bind=../workload.nix=" + identities["workload.nix"]]),
    }
    for name, options in refusals.items():
        completed, record, invocations = observe(f"refused-{name}", **options)
        case(f"refused-{name}", completed.returncode == 2 and record is None and not invocations
             and not (output / "observations" / f"refused-{name}").exists(), {"stderr": completed.stderr[-400:]})

    mapping = output / "mapping"
    tree = mapping / "tree"
    (tree / "src").mkdir(parents=True)
    (tree / "src" / "a.nix").write_bytes(b"let\n  f = x: x;\nin f\n")
    repository = mapping / "repository"
    (repository / "src").mkdir(parents=True)
    (repository / "src" / "b.nix").write_bytes(b"{\n  check = value: value;\n}\n")
    (repository / "src" / "c.nix").write_bytes(b"one\n")
    git = ["git", "-C", str(repository), "-c", "user.name=qualification", "-c", "user.email=qualification@localhost",
           "-c", "commit.gpgsign=false", "-c", "init.defaultBranch=main"]
    subprocess.run(git[:3] + ["init", "--quiet"], check=True)
    subprocess.run(git + ["add", "src"], check=True)
    subprocess.run(git + ["commit", "--quiet", "-m", "fixture"], check=True)
    revision = subprocess.check_output(git[:3] + ["rev-parse", "HEAD"], text=True).strip()
    (repository / "src" / "c.nix").write_bytes(b"changed after commit\n")
    store = mapping / "store"
    entry = store / ("a" * 32 + "-source") / "src"
    entry.mkdir(parents=True)
    (entry / "b.nix").write_bytes(b"{\n  check = value: value;\n}\n")
    (entry / "c.nix").write_bytes(b"changed after commit\n")
    (entry / "d.nix").write_bytes(b"unbound\n")
    (tree / "inner").mkdir()
    (tree / "inner" / "e.nix").write_bytes(b"inner\n")
    roots = [{"name": "tree", "tree": str(tree), "manifest": {"src/a.nix": {"sha256": hashlib.sha256(b"let\n  f = x: x;\nin f\n").hexdigest()}}},
             {"name": "inner", "tree": str(tree / "inner")},
             {"name": "dependency", "git": str(repository), "revision": revision}]
    folded = (f"{tree}/src/a.nix:2:7:f 3\n{tree}/src/a.nix:2:7:f;{entry}/b.nix:2:11:check 2\n"
              f"{entry}/c.nix:1:1 1\n{entry}/d.nix:1:1 1\n«string»:1:1:primop head 1\n{tree}/src/a.nix:9:1 1\n{tree}/src/a.nix:2:40 1\n"
              f"{tree}/inner/e.nix:1:1 1\n«github:owner/repository/{revision}?narHash=x»/src/b.nix:2:11:check 1\n"
              f"«path:{tree}»/src/a.nix:2:7:f 1\n«github:other/unrelated/{'0' * 40}»/lib/x.nix:1:1 1\n"
              f"«github:owner/repository/{revision}»/src/c.nix:1:1 1\n")
    observation = mapping / "observation"
    observation.mkdir()
    (observation / "profile.folded").write_text(folded)
    (observation / "record.json").write_text(json.dumps({"instrumentation": {
        "mode": "flamegraph", "valid": True, "record": str(observation / "profile.folded"),
        "sha256": hashlib.sha256(folded.encode()).hexdigest()}}))
    mapped = map_record(observation, roots, str(store))
    positions = mapped["positions"]
    def status(display):
        return positions[display]["status"]
    case("map-statuses", status(f"{tree}/src/a.nix:2:7") == "mapped" and positions[f"{tree}/src/a.nix:2:7"]["excerpt"].startswith("x: x;")
         and status(f"{entry}/b.nix:2:11") == "mapped" and positions[f"{entry}/b.nix:2:11"]["root"] == "dependency"
         and positions[f"{entry}/b.nix:2:11"]["excerpt"].startswith("value: value;")
         and status(f"{entry}/c.nix:1:1") == "unbound" and status(f"{entry}/d.nix:1:1") == "unbound"
         and status("«string»:1:1") == "unmapped-origin" and status(f"{tree}/src/a.nix:9:1") == "position-outside-file"
         and status(f"{tree}/src/a.nix:2:40") == "position-outside-line", mapped)
    mounted = f"«github:owner/repository/{revision}?narHash=x»/src/b.nix:2:11"
    case("map-nested-and-mounted", positions[f"{tree}/inner/e.nix:1:1"]["root"] == "inner"
         and status(mounted) == "mapped" and positions[mounted]["root"] == "dependency"
         and positions[mounted]["excerpt"].startswith("value: value;")
         and status(f"«path:{tree}»/src/a.nix:2:7") == "mapped" and positions[f"«path:{tree}»/src/a.nix:2:7"]["root"] == "tree"
         and status(f"«github:other/unrelated/{'0' * 40}»/lib/x.nix:1:1") == "unbound"
         and status(f"«github:owner/repository/{revision}»/src/c.nix:1:1") == "mapped"
         and positions[f"«github:owner/repository/{revision}»/src/c.nix:1:1"]["excerpt"] == "one", mapped["statuses"])
    roots[0]["manifest"]["src/a.nix"]["sha256"] = "0" * 64
    case("map-stale-manifest", map_record(observation, roots, str(store))["positions"][f"{tree}/src/a.nix:2:7"]["status"] == "stale", None)
    (observation / "profile.folded").write_text(folded + "«string»:1:1 1\n")
    try:
        map_record(observation, roots, str(store))
        case("map-record-changed", False, None)
    except RecordError as error:
        case("map-record-changed", error.kind == "stale", str(error))

    # the writer's grammar, case by case, without an observer launch
    def kind(parse, data):
        try:
            parse(data)
            return "valid"
        except RecordError as error:
            return error.kind
    def stats(functions, **changes):
        return statistics_fixture(functions=functions, nrFunctionCalls=sum(e["count"] for e in functions), **changes).encode()
    entry = {"name": "check", "file": "/q/fixture/praxis.nix", "line": 10, "column": 12, "count": 4}
    grammar = {
        "counter-boolean": (stats([entry], nrThunks=True), "malformed"),
        "counter-negative": (stats([entry], nrLookups=-1), "malformed"),
        "primop-count-boolean": (stats([entry], primops={"import": True}, nrPrimOpCalls=1), "malformed"),
        "function-count-boolean": (statistics_fixture(functions=[dict(entry, count=True)], nrFunctionCalls=1).encode(), "malformed"),
        "function-line-zero": (stats([dict(entry, line=0)]), "malformed"),
        "function-line-boolean": (stats([dict(entry, line=True)]), "malformed"),
        "function-column-negative": (stats([dict(entry, column=-1)]), "malformed"),
        "function-line-without-column": (stats([{k: v for k, v in entry.items() if k != "column"}]), "malformed"),
        "function-file-without-position": (stats([{"name": "check", "file": "/q/fixture/praxis.nix", "count": 4}]), "malformed"),
        "function-name-missing": (stats([{k: v for k, v in entry.items() if k != "name"}]), "malformed"),
        "function-unpositioned": (stats([{"name": None, "count": 2}]), "valid"),
        "function-without-file": (stats([{"name": "f", "line": 1, "column": 1, "count": 2}]), "valid"),
        "function-column-zero": (stats([dict(entry, column=0)]), "valid"),
    }
    found = {name: kind(statistics, data) for name, (data, _) in grammar.items()}
    case("statistics-grammar", all(found[name] == expected for name, (_, expected) in grammar.items()), found)
    folded = {
        "column-zero": (b"/q/fixture/praxis.nix:10:0:check 1\n", "malformed"),
        "line-leading-zero": (b"/q/fixture/praxis.nix:010:12:check 1\n", "malformed"),
        "column-leading-zero": (b"/q/fixture/praxis.nix:10:012 1\n", "malformed"),
        "unresolved-none": (b"\xc2\xabnone\xc2\xbb:0 1\n", "valid"),
        "upstream-frames": (FOLDED.encode(), "valid"),
    }
    found = {name: kind(folded_stacks, data) for name, (data, _) in folded.items()}
    case("folded-grammar", all(found[name] == expected for name, (_, expected) in folded.items()), found)
    for mode, content in (("flamegraph", "/q/fixture/praxis.nix:10:0:check 1\n"), ("counts", stats([dict(entry, line=True)]).decode())):
        rejected(f"{mode}-invalid-position", mode, {"stdout": valid_output, "record": content}, "malformed")

    counted = mapping / "counted"
    counted.mkdir()
    statistics_record = statistics_fixture(functions=[
        {"name": "f", "file": f"{tree}/src/a.nix", "line": 2, "column": 0, "count": 2},
        {"name": "f", "file": f"{tree}/src/a.nix", "line": 2, "column": 7, "count": 1},
        {"name": None, "line": 1, "column": 1, "count": 2}, {"name": None, "count": 2}], nrFunctionCalls=7)
    (counted / "stats.json").write_text(statistics_record)
    (counted / "record.json").write_text(json.dumps({"instrumentation": {
        "mode": "counts", "valid": True, "record": str(counted / "stats.json"),
        "sha256": hashlib.sha256(statistics_record.encode()).hexdigest()}}))
    roots[0]["manifest"]["src/a.nix"]["sha256"] = hashlib.sha256(b"let\n  f = x: x;\nin f\n").hexdigest()
    mapped = map_record(counted, roots, str(store))
    line_level, exact = mapped["positions"][f"{tree}/src/a.nix:2:0"], mapped["positions"][f"{tree}/src/a.nix:2:7"]
    case("map-column-zero-line-level", line_level["status"] == "mapped" and line_level["column_recorded"] is False
         and line_level["byte_offset"] == 4 and line_level["excerpt"] == "  f = x: x;" and exact["byte_offset"] == 10
         and exact["excerpt"] == "x: x;" and line_level["content_sha256"] == exact["content_sha256"]
         and sum(1 for e in mapped["functions"] if "position" not in e) == 2, mapped["positions"])
    unresolved = mapping / "unresolved"
    unresolved.mkdir()
    folded_record = f"{tree}/src/a.nix:0:f 1\n{tree}/src/a.nix:3 1\n"
    (unresolved / "profile.folded").write_text(folded_record)
    (unresolved / "record.json").write_text(json.dumps({"instrumentation": {
        "mode": "flamegraph", "valid": True, "record": str(unresolved / "profile.folded"),
        "sha256": hashlib.sha256(folded_record.encode()).hexdigest()}}))
    positions = map_record(unresolved, roots, str(store))["positions"]
    case("map-line-zero-unresolved", positions[f"{tree}/src/a.nix:0"]["status"] == "position-unresolved"
         and positions[f"{tree}/src/a.nix:3"]["status"] == "mapped" and positions[f"{tree}/src/a.nix:3"]["excerpt"] == "in f",
         positions)

    summary = {"passed": all(r["passed"] for r in results), "cases": len(results),
               "evaluator_invocations": sum(1 for _ in log.open()) if log.exists() else 0,
               "observer_path": str(fake), "results": results}
    (output / "qualification.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({key: summary[key] for key in ("passed", "cases", "evaluator_invocations")}))
    failed = [r["case"] for r in results if not r["passed"]]
    if failed:
        raise SystemExit("failed qualification cases " + " ".join(failed))


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    qualification = commands.add_parser("qualify")
    qualification.add_argument("--output", type=Path, required=True)
    mapping = commands.add_parser("map")
    mapping.add_argument("--observation", type=Path, required=True)
    mapping.add_argument("--roots", type=Path, required=True)
    mapping.add_argument("--store", default=os.environ.get("NIX_STORE", "/nix/store"))
    mapping.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "qualify":
        qualify(args.output)
        return
    if args.output.exists():
        parser.error(f"refusing to replace {args.output}")
    try:
        result = map_record(args.observation, roots_from(args.roots), args.store)
    except RecordError as error:
        raise SystemExit(f"{error.kind} instrumentation {error}")
    args.output.write_text(json.dumps(result, indent=1) + "\n")
    print(json.dumps({"mode": result["mode"], "statuses": result["statuses"]}))


if __name__ == "__main__":
    main()
