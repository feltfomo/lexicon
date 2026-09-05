import argparse
import json
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument("runner", type=Path)
parser.add_argument("--repetitions", type=int, default=5)
parser.add_argument("--nix-count", type=int, default=2000)
args = parser.parse_args()
if args.repetitions < 1 or args.nix_count < 1:
    parser.error("counts must be positive")
runner = args.runner.resolve()
repository = Path(__file__).resolve().parents[2]
results = {"machine": platform.machine(), "kernel": platform.release(), "cases": {}}


def measure(name, command, cwd):
    subprocess.run(command, cwd=cwd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True, timeout=120)
    samples = []
    for _ in range(args.repetitions):
        started = time.perf_counter()
        subprocess.run(command, cwd=cwd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True, timeout=120)
        samples.append(time.perf_counter() - started)
    results["cases"][name] = {"seconds": samples, "median_seconds": statistics.median(samples)}


def step():
    return {"kind": "exec", "exec": ["true"], "args": [], "label": "true", "cwd": None,
            "env": {}, "interactive": False, "confirm": None, "forwardArgs": False}


def manifest(steps, parameters=None, env=None):
    return {"version": 1, "bash": "/bin/sh",
            "project": {"cwd": None, "discoverRoot": None, "requireRoot": False, "expectedFlake": None},
            "commands": {"bench": {"description": "benchmark", "steps": steps,
                                   "parameters": parameters or [], "cwd": None, "env": env or {},
                                   "path": "", "lock": None}}}


with tempfile.TemporaryDirectory(prefix="praxis-benchmark-") as directory:
    root = Path(directory)
    cases = [
        ("run-100-short-steps", "run", manifest([step() for _ in range(100)]), []),
        ("plan-3000-steps-256-env", "plan",
         manifest([step() for _ in range(3000)], env={f"VALUE_{i}": "x" * 64 for i in range(256)}), []),
        ("plan-2000-parameters", "plan",
         manifest([step()], parameters=[{"name": f"arg{i}", "description": "", "type": "string",
                                         "required": True, "positional": False, "default": None}
                                        for i in range(2000)]), [f"--arg{i}=value" for i in range(2000)]),
    ]
    large = manifest([step()])
    large["commands"] = {f"cmd{i}": dict(large["commands"]["bench"]) for i in range(10000)}
    cases.extend([
        ("list-10000-commands", "list", large, []),
        ("complete-10000-commands", "complete", large, ["run", "cmd99"]),
    ])
    for name, action, value, arguments in cases:
        path = root / f"{name}.json"
        path.write_text(json.dumps(value))
        target = [] if action in ["list", "complete"] else ["bench"]
        measure(name, [str(runner), "--manifest", str(path), action, *target, *arguments], root)

expression = (
    'let flake = builtins.getFlake ("path:" + toString ./.); '
    'in import ./tests/praxis/benchmark.nix '
    f'{{ praxis = flake.lib.praxis; count = {args.nix_count}; }}'
)
measure(f"nix-{args.nix_count}-parameters", ["nix", "eval", "--json", "--impure", "--expr", expression], repository)
print(json.dumps(results, indent=2))
