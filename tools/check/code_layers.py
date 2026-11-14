#!/usr/bin/env python3
"""Checks the four layers of the code (docs/CODE_LAGEN.md) in the folders that follow them.

    <name>_rules.gd    logic     extends RefCounted, only static functions, no state, no nodes
    <name>_layout.gd   layout    the same, and no colours or fonts
    <name>_view.gd     graphics  decides nothing: no rules, no input, no pausing
    <name>.gd          behaviour (beside a _view): no colours, fonts or theme overrides
    every script       its own unit test: tests/unit/**/test_<script>.gd

    python3 tools/check/code_layers.py                    the folders in LAYERED_FOLDERS
    python3 tools/check/code_layers.py scripts/ui/hud     only that folder (or one file)

Exit code 1 when something is in the wrong layer. It reads the text of the scripts, so it
finds what is plainly there (a `var` in a rules file, `Color(` in a behaviour), not every
way to break the rule.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
## The folders whose scripts are in the four layers; add a folder when it is brought over.
LAYERED_FOLDERS = ["scripts/ui/hud", "scripts/ui/screens", "scripts/audio/city_music.gd", "scripts/audio/city_music_rules.gd"]

FUNCTION = re.compile(r"^(static )?func (\w+)\(", re.MULTILINE)
MEMBER = re.compile(r"^(?:@\w+(?:\([^)]*\))? )*var (\w+)", re.MULTILINE)
PRELOAD = re.compile(r'preload\("res://([^"]+)"\)')
## What only something with nodes does: not for logic and layout.
NODE_WORK = [r"\bget_tree\(", r"\badd_child\(", r"\bcreate_tween\(", r"\bqueue_free\(", r"\bInput\.", r"\bget_node", r"\.new\(\)"]
## What only graphics does: not for logic, layout and behaviour.
LOOKS = [r"\bColor\(", r"\badd_theme_\w+\(", r"\bUiStyle\.(?:font|fonts|label|box_style|shadowed_panel|menu_item_style|faux_3d)\b"]
## What only behaviour does: not for a view.
DECISIONS = [r"func _input\(", r"func _unhandled_input\(", r"\bInput\.", r"\.paused\s*=", r"\bis_action_pressed\("]


def layer_of(path: pathlib.Path, siblings: set[str]) -> str:
    """The layer of a script by its name: rules, layout, view, behaviour (it has a view
    beside it) or "" (a script on its own, such as shared looks)."""
    stem = path.stem
    for suffix in ("rules", "layout", "view"):
        if stem.endswith("_" + suffix):
            return suffix
    return "behaviour" if stem + "_view" in siblings else ""


def code_only(source: str) -> str:
    """The source without comments and without the text inside strings."""
    lines = []
    for line in source.splitlines():
        line = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)
        lines.append(line.split("#", 1)[0])
    return "\n".join(lines)


def found(patterns: list[str], code: str) -> list[str]:
    return sorted({match.group(0) for pattern in patterns for match in re.finditer(pattern, code)})


def problems_of(path: pathlib.Path, siblings: set[str], test_names: set[str]) -> list[str]:
    """What is in the wrong layer in one script."""
    source = path.read_text()
    code = code_only(source)
    layer = layer_of(path, siblings)
    problems = []
    if f"test_{path.stem}" not in test_names:
        problems.append(f"geen unit-test (tests/unit/**/test_{path.stem}.gd)")
    preloads = [pathlib.PurePosixPath(found_path).stem for found_path in PRELOAD.findall(source)]
    if layer in ("rules", "layout"):
        if not re.search(r"^extends RefCounted$", source, re.MULTILINE):
            problems.append("logica/layout hoort `extends RefCounted` te zijn")
        loose = [name for is_static, name in FUNCTION.findall(code) if not is_static]
        if loose:
            problems.append("niet-statische functies: " + ", ".join(loose))
        members = MEMBER.findall(code)
        if members:
            problems.append("toestand (var): " + ", ".join(members))
        if found(NODE_WORK, code):
            problems.append("werk met nodes: " + ", ".join(found(NODE_WORK, code)))
        if found(LOOKS, code):
            problems.append("uiterlijk (hoort in de view): " + ", ".join(found(LOOKS, code)))
        wrong = [name for name in preloads if name.endswith("_view") or name + "_view" in siblings]
        if wrong:
            problems.append("kent view of gedrag: " + ", ".join(wrong))
    if layer == "layout" and any(name.endswith("_rules") for name in preloads):
        problems.append("layout kent de logica: " + ", ".join(name for name in preloads if name.endswith("_rules")))
    if layer == "view":
        if any(name.endswith("_rules") for name in preloads):
            problems.append("de view beslist niets, maar kent: " + ", ".join(name for name in preloads if name.endswith("_rules")))
        if found(DECISIONS, code):
            problems.append("invoer of pauze (hoort in het gedrag): " + ", ".join(found(DECISIONS, code)))
    if layer == "behaviour" and found(LOOKS, code):
        problems.append("uiterlijk (hoort in de view): " + ", ".join(found(LOOKS, code)))
    return problems


def main() -> int:
    places = sys.argv[1:] or LAYERED_FOLDERS
    test_names = {path.stem for path in (ROOT / "tests" / "unit").rglob("test_*.gd")}
    scripts = 0
    wrong = 0
    for place in places:
        target = (ROOT / place).resolve()
        paths = sorted(target.rglob("*.gd")) if target.is_dir() else [target]
        for path in paths:
            siblings = {other.stem for other in path.parent.glob("*.gd")}
            problems = problems_of(path, siblings, test_names)
            scripts += 1
            if problems:
                wrong += 1
                print(f"{path.relative_to(ROOT).as_posix()}  ({layer_of(path, siblings) or 'los'})")
                for problem in problems:
                    print(f"    {problem}")
    print(f"LAGEN {scripts - wrong}/{scripts} scripts in orde" + ("" if wrong == 0 else f"; {wrong} met iets in de verkeerde laag"))
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
