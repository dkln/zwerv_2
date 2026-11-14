#!/usr/bin/env python3
"""Which public functions of the game's scripts have a unit test.

A function counts as covered when a unit test file (tests/unit/**/test_*.gd) that loads its
script (a preload/load of the script's path, or of a script that extends it) calls it by
name (`name(` or `.name` as a Callable). Public: no leading underscore. This is a count by
name, not a measurement of the lines that ran: it shows what has no test at all.

    python3 tools/check/unit_coverage.py                 every script in scripts/
    python3 tools/check/unit_coverage.py scripts/ui      only that folder (or one file)
    python3 tools/check/unit_coverage.py --missing       only the scripts with gaps
    python3 tools/check/unit_coverage.py --min 80        exit code 1 below 80 % in total
"""
import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
PUBLIC_FUNCTION = re.compile(r"^(?:static )?func ([a-z][A-Za-z0-9_]*)\(", re.MULTILINE)
EXTENDS_PATH = re.compile(r'^extends "(res://[^"]+)"', re.MULTILINE)
CLASS_NAME = re.compile(r"^class_name (\w+)", re.MULTILINE)


def public_functions(source: str) -> list[str]:
    """The names of the public functions of a script, in the order they stand in it."""
    return list(dict.fromkeys(PUBLIC_FUNCTION.findall(source)))


def loads_script(test_source: str, script_path: str, class_name: str) -> bool:
    """Whether a test file loads the script: by its path, or by its class_name."""
    if f"res://{script_path}" in test_source:
        return True
    return bool(class_name) and re.search(rf"\b{re.escape(class_name)}\b", test_source) is not None


def calls(test_source: str, function_name: str) -> bool:
    """Whether a test file calls the function, or hands it on as a Callable."""
    return re.search(rf"(?<![A-Za-z0-9_]){re.escape(function_name)}\(|\.{re.escape(function_name)}\b", test_source) is not None


def survey(script_folder: pathlib.Path) -> list[dict]:
    """Per script: its public functions and the ones no unit test calls."""
    tests = [path.read_text() for path in sorted((ROOT / "tests" / "unit").rglob("test_*.gd"))]
    scripts = sorted(script_folder.rglob("*.gd")) if script_folder.is_dir() else [script_folder]
    sources = {path.relative_to(ROOT).as_posix(): path.read_text() for path in sorted((ROOT / "scripts").rglob("*.gd"))}
    # a test of a script that extends another also tests what it inherits
    children: dict[str, list[str]] = {}
    for path, source in sources.items():
        for parent in EXTENDS_PATH.findall(source):
            children.setdefault(parent.removeprefix("res://"), []).append(path)
    rows = []
    for script in scripts:
        path = script.relative_to(ROOT).as_posix()
        source = sources.get(path, script.read_text())
        names = public_functions(source)
        family = [path] + children.get(path, [])
        own_tests = [test for test in tests if any(
            loads_script(test, member, "".join(CLASS_NAME.findall(sources.get(member, ""))[:1])) for member in family)]
        missing = [name for name in names if not any(calls(test, name) for test in own_tests)]
        rows.append({"path": path, "functions": names, "missing": missing, "tests": len(own_tests)})
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("where", nargs="?", default="scripts", help="folder or script (default: scripts)")
    parser.add_argument("--missing", action="store_true", help="only the scripts with functions without a test")
    parser.add_argument("--min", type=float, default=0.0, help="exit code 1 when the total is below this percentage")
    arguments = parser.parse_args()
    rows = survey((ROOT / arguments.where).resolve())
    total = sum(len(row["functions"]) for row in rows)
    covered = total - sum(len(row["missing"]) for row in rows)
    for row in rows:
        if arguments.missing and not row["missing"]:
            continue
        count = len(row["functions"])
        print(f"{count - len(row['missing']):3d}/{count:<3d} {row['path']}" + ("" if row["tests"] else "   (geen unit-test)"))
        if row["missing"]:
            print("        zonder test: " + ", ".join(row["missing"]))
    without_tests = sum(1 for row in rows if not row["tests"] and row["functions"])
    share = 100.0 * covered / total if total else 100.0
    print(f"TOTAAL {covered}/{total} publieke functies met een unit-test ({share:.0f} %); "
          f"{without_tests} van {len(rows)} scripts met publieke functies zonder enige unit-test")
    return 1 if share < arguments.min else 0


if __name__ == "__main__":
    sys.exit(main())
