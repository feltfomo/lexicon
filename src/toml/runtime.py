"""TOML construction, merge and serialized publication share one parser."""
import argparse
import contextlib
import fcntl
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

import tomlkit as toml
from tomlkit.items import Table, InlineTable, Integer
from tomlkit.container import OutOfOrderTableProxy


class Error(ValueError):
    pass


def validate(value, source, path="$"):
    if isinstance(value, (int, Integer)) and not isinstance(value, bool):
        if not -(2**63) <= value < 2**63:
            raise Error(f"{source}: {path}: integer outside signed 64-bit range")
    if hasattr(value, "items"):
        for key, item in value.items():
            validate(item, source, f"{path}.{key}")
    elif isinstance(value, (list, tuple)):
        for index, item in enumerate(value):
            validate(item, source, f"{path}[{index}]")


def parse(text, source):
    try:
        doc = toml.parse(text)
        validate(doc, source)
        return doc
    except Exception as exc:
        raise Error(f"{source}: {exc}") from exc


def construct(node, path="$", inline=False):
    kind, value = node["kind"], node["value"]
    if kind == "float":
        spelling = value if any(c in value for c in ".eE") else value + ".0"
        return parse("value = " + spelling, path).item("value")
    if kind == "literal":
        doc = parse("value = " + value, path)
        if list(doc) != ["value"]:
            raise Error(f"{path}: literal must contain exactly one value")
        return doc.item("value")
    if kind == "document":
        if path != "$":
            raise Error(f"{path}: document is only valid as the whole input")
        return parse(value, path)
    if kind == "inline":
        if value["kind"] != "table":
            raise Error(f"{path}: inline requires attributes")
        result = toml.inline_table()
        for key, item in value["value"].items():
            result[key] = construct(item, f"{path}.{key}", inline=True)
        return result
    if kind == "tables":
        if value["kind"] != "array":
            raise Error(f"{path}: tables requires a list")
        result = toml.aot() if value["value"] and not inline else toml.array()
        for index, item in enumerate(value["value"]):
            if item["kind"] != "table":
                raise Error(f"{path}[{index}]: arrays of tables require attributes")
            result.append(construct(item, f"{path}[{index}]", inline=inline))
        return result
    if kind == "table":
        result = toml.inline_table() if inline else toml.table()
        for key, item in value.items():
            result[key] = construct(item, f"{path}.{key}", inline=inline)
        return result
    if kind == "array":
        tables = not inline and value and all(item["kind"] == "table" for item in value)
        result = toml.aot() if tables else toml.array()
        for index, item in enumerate(value):
            result.append(construct(item, f"{path}[{index}]", inline=not tables))
        return result
    if kind != "scalar" or value is None:
        raise Error(f"{path}: invalid TOML value")
    validate(value, "Nix", path)
    return toml.item(value)


def generate(value):
    result = construct(value)
    if not hasattr(result, "items") or isinstance(result, InlineTable):
        raise Error("$: document must be an attribute set")
    return checked_text(toml.dumps(result), "generated document")


def checked_text(text, source):
    parse(text, source)
    return text


def body_of(value):
    if isinstance(value, OutOfOrderTableProxy):
        # TOML Kit exposes split tables as a proxy without a public body API.
        # Its concrete tables keep the trivia that a dict conversion discards.
        return (pair for table in value._tables for pair in table.value.body)
    return (value.value if isinstance(value, (Table, InlineTable)) else value).body


def item_of(value, key):
    return value[key] if isinstance(value, OutOfOrderTableProxy) else value.item(key)


def append_item(target, key, item):
    if isinstance(target, OutOfOrderTableProxy):
        if key is None:
            target._tables[-1].append(None, item)
        else:
            target[key] = item
    else:
        target.append(key, item)


def merge_into(target, incoming, conflict, source, path="$"):
    table_types = (Table, InlineTable, OutOfOrderTableProxy)
    for key, item in body_of(incoming):
        if key is None:
            append_item(target, None, item)
            continue
        name = key.key
        if name not in target:
            append_item(target, key, item)
            continue
        previous = item_of(target, name)
        if isinstance(previous, table_types) and isinstance(item, table_types):
            merge_into(previous, item, conflict, source, f"{path}.{name}")
        elif conflict == "last":
            target[name] = item
        elif conflict == "error":
            raise Error(f"{source}: conflicting value at {path}.{name}")


def merged(documents, conflict):
    result = None
    for source, text in documents:
        doc = parse(text, source)
        if result is None:
            result = doc
        else:
            merge_into(result, doc, conflict, source)
    return checked_text(toml.dumps(result if result is not None else toml.document()), "merged document")


def read(path):
    return Path(path).read_text(encoding="utf-8")


def atomic(path, data, mode=0o600):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".lexicon-toml-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            os.fchmod(stream.fileno(), mode)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(temporary)


def publish(descriptor, theme=None):
    # The stable descriptor path is resolved after taking the destination lock.
    # Old renderer hooks therefore cannot resurrect an old declarative base.
    initial = json.loads(read(descriptor))
    state = Path(initial["state"])
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (state / "lock").open("a+b") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        spec = json.loads(read(descriptor))
        destination = Path(spec["output"])
        mode = 0o600
        if destination.exists() or destination.is_symlink():
            info = destination.lstat()
            if not stat.S_ISREG(info.st_mode):
                raise Error(f"{destination}: output must be a regular file")
            mode = stat.S_IMODE(info.st_mode)
        base = read(spec["base"])
        cache = state / "accepted.toml"
        accepted = read(theme) if theme else (read(cache) if cache.exists() else None)
        documents = [(spec["base"], base)]
        if accepted is not None:
            documents.append((str(theme or cache), accepted))
        output = merged(documents, spec["conflict"]).encode()
        # Commit accepted theme first. If interrupted before final publication,
        # the next activation deterministically regenerates the intended output.
        if theme and (not cache.exists() or cache.read_bytes() != accepted.encode()):
            atomic(cache, accepted.encode())
        changed = not destination.exists() or destination.read_bytes() != output
        pending = state / "reload-pending"
        if changed:
            atomic(pending, b"pending\n")
            atomic(destination, output, mode)
        if pending.exists():
            if spec.get("reload"):
                environment = os.environ.copy()
                environment.setdefault("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
                environment.setdefault("DBUS_SESSION_BUS_ADDRESS", f"unix:path={environment['XDG_RUNTIME_DIR']}/bus")
                subprocess.run(spec["reload"], shell=True, executable=spec["shell"], env=environment, check=True)
            pending.unlink()


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    gen = sub.add_parser("generate")
    gen.add_argument("input")
    gen.add_argument("output")
    merge = sub.add_parser("merge")
    merge.add_argument("--conflict", choices=["error", "first", "last"], default="error")
    merge.add_argument("output")
    merge.add_argument("sources", nargs="+")
    pub = sub.add_parser("publish")
    pub.add_argument("descriptor")
    pub.add_argument("--theme")
    args = parser.parse_args()
    try:
        if args.command == "generate":
            Path(args.output).write_text(generate(json.loads(read(args.input))), encoding="utf-8")
        elif args.command == "merge":
            Path(args.output).write_text(merged([(p, read(p)) for p in args.sources], args.conflict), encoding="utf-8")
        else:
            publish(args.descriptor, args.theme)
    except (Error, OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as exc:
        print(f"lexicon-toml: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
