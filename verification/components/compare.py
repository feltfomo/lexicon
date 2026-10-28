#!/usr/bin/env python3
"""compare equal projections with a fixed sample schedule"""

import argparse
import json
from pathlib import Path
import statistics
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--components", nargs="+", default=["ownerships", "registry", "declaration", "resource", "toml", "praxis"])
    parser.add_argument("--sizes", type=int, choices=[4, 16, 64], nargs="+", default=[4, 16, 64])
    parser.add_argument("--initialize-report", action="store_true")
    parser.add_argument("--stop-on-regression", action="store_true")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    sources = {"baseline": args.baseline, "candidate": args.candidate}
    comparisons = []
    for component in args.components:
        for size in args.sizes:
            records = {"baseline": [], "candidate": []}
            digest = None
            identities = {}
            schedule = [("warm", "baseline"), ("warm", "candidate")]
            for pair in range(3):
                order = ("baseline", "candidate") if pair % 2 == 0 else ("candidate", "baseline")
                schedule.extend((str(pair), side) for side in order)
            for repetition, side in schedule:
                target = args.output / f"{component}-{size}-{repetition}-{side}"
                command = [
                    sys.executable, str(Path(__file__).with_name("observe.py")),
                    "--source", sources[side], "--component", component,
                    "--size", str(size), "--output", str(target),
                ]
                if args.initialize_report:
                    command.append("--initialize-report")
                subprocess.run(command, check=True)
                record = json.loads((target / "record.json").read_text())
                if not record["admitted"] or not record["process_released"]:
                    raise RuntimeError(f"unusable sample {target}")
                if component == "toml":
                    identity = json.loads((target / "stdout").read_text())["value"]
                    if side in identities and identities[side] != identity:
                        raise RuntimeError(f"derivation identity changed within source {target}")
                    identities[side] = identity
                elif digest is None:
                    digest = record["sha256"]
                elif digest != record["sha256"]:
                    raise RuntimeError(f"projection mismatch {target}")
                if repetition != "warm":
                    records[side].append(record)
            medians = {
                side: {metric: statistics.median(record[metric] for record in samples)
                       for metric in ("wall_seconds", "peak_rss_kib", "output_bytes")}
                for side, samples in records.items()
            }
            baseline, candidate = medians["baseline"], medians["candidate"]
            comparison = {
                "component": component, "size": size, "medians": medians,
                "derivation_identities": identities,
                "equal_output_required": component != "toml",
                "wall_within_noise": candidate["wall_seconds"] <= baseline["wall_seconds"] * 1.35 + 0.03,
                "rss_within_noise": candidate["peak_rss_kib"] <= baseline["peak_rss_kib"] * 1.25 + 8192,
            }
            comparisons.append(comparison)
            (args.output / "comparisons.json").write_text(json.dumps(comparisons, indent=2) + "\n")
            if args.stop_on_regression and not (comparison["wall_within_noise"] and comparison["rss_within_noise"]):
                raise RuntimeError(f"component regression {component} at size {size}")


if __name__ == "__main__":
    main()
