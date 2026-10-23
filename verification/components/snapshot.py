"""freeze admitted working files with content, kind and executable identities"""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def manifest(root, names):
    result = {}
    for name in names:
        path = root / name
        if path.is_symlink():
            result[name] = {"kind": "symlink", "target": str(path.readlink())}
        elif path.is_file():
            result[name] = {"kind": "file", "executable": bool(path.stat().st_mode & 0o111),
                            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        else:
            raise ValueError(f"unsupported admitted path {path}")
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    names = sorted(set(filter(None, subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=root
    ).decode().split("\0"))))
    before = manifest(root, names)
    args.output.mkdir(parents=True, exist_ok=False)
    source = args.output / "source"
    for name in names:
        target = source / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / name, target, follow_symlinks=False)
    assert before == manifest(source, names) == manifest(root, names)
    assert names == sorted(str(p.relative_to(source)) for p in source.rglob("*") if p.is_symlink() or not p.is_dir())
    (args.output / "manifest.json").write_text(json.dumps(before, indent=2) + "\n")
    identity = {"source": "path:" + str(source.resolve()), "files": len(names),
                "manifest_sha256": hashlib.sha256(json.dumps(before, sort_keys=True).encode()).hexdigest(),
                "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()}
    (args.output / "identity.json").write_text(json.dumps(identity, indent=2) + "\n")
    print(json.dumps(identity))


if __name__ == "__main__":
    main()
