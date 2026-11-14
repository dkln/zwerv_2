"""One composition in JSON (docs/MUZIEK_JSON.md) rendered to one OGG file, to listen to it: the
composition as written, played once with the Mega Drive sound the game's music is made with,
and nothing else.

    tools/muziek/json_naar_ogg.sh <compositie.json> <uitvoer.ogg>

Nothing of the game changes: no composities/<naam>.py, not composities/actief.py, no file in
assets/audio/muziek/ (an output path in that folder is refused), no derived pieces.

The file goes the way a base composition goes, only in a temporary folder: read by json_bron.py
(the usual and the flat form) or tijdlijn.py (the full timeline), written as a composition file,
loaded by score.py, and played as the intro is (derive.intro: once, ringing out) by mixer.py:
the usual and the flat form by the rebuilt synth of the composer's tracker, the timeline by its
own FM patches on the chip imitation.
"""
import argparse
import dataclasses
import importlib
import json
import os
import pathlib
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import derive  # noqa: E402
import json_bron  # noqa: E402
import mixer  # noqa: E402
import score as score_module  # noqa: E402
import standaardvorm  # noqa: E402
import tijdlijn  # noqa: E402
import tracker  # noqa: E402

MUSIC_FOLDER = os.path.join(score_module.PROJECT, "assets", "audio", "muziek")
## The temporary composition files get a name no composition in composities/ has.
MODULE_PREFIX = "json_naar_ogg_"


def load_json(json_path: str):
    """The file's JSON; a ValueError (Dutch) when it is not there or not JSON."""
    if not os.path.isfile(json_path):
        raise ValueError(f"{json_path}: het bestand bestaat niet")
    try:
        with open(json_path, encoding="utf-8") as json_file:
            return json.load(json_file)
    except json.JSONDecodeError as error:
        raise ValueError(f"{json_path}: geen geldig JSON (regel {error.lineno}, kolom {error.colno}: {error.msg})")
    except UnicodeDecodeError:
        raise ValueError(f"{json_path}: geen geldig JSON (geen UTF-8-tekst)")


def unknown_form(data) -> str:
    """Why the JSON is none of the forms that are read (Dutch), or "" when it is one of them."""
    if tijdlijn.is_timeline(data) or json_bron.is_flat(data):
        return ""
    if isinstance(data, dict) and isinstance(data.get("bars"), list):
        return ""   # the usual form (json_bron.problems says what is missing in it)
    keys = ", ".join(str(key) for key in data) if isinstance(data, dict) else type(data).__name__
    return ("onbekende vorm: niet de standaardvorm van docs/MUZIEK_JSON.md ('metadata', 'sections', 'synthParameters' "
            "en 'bars') en ook niet de platte vorm of de tijdlijn. Zet het bestand eerst om: "
            "tools/muziek/naar_standaardvorm.sh <bestand.json>"
            f"\n  Het bestand heeft: {keys}")


def piece_as_written(json_path: str, piece_name: str) -> tuple:
    """(the mixer.Piece that plays the composition of the file once as written, the warnings of
    its reader: what is not played as the file says). A ValueError (Dutch) when the file cannot
    be used."""
    json_path = os.path.abspath(json_path)
    data = load_json(json_path)
    wrong = unknown_form(data)
    if wrong:
        raise ValueError(f"{json_path}: {wrong}")
    module_name = MODULE_PREFIX + tracker.default_name(json_path)
    try:
        if standaardvorm.synth_of(data) == "patches":
            # the standard form with its own sounds: "patch:<the file's full path>:<voice>"
            source = standaardvorm.read(json_path)
            warnings = list(source["warnings"])
            source_text = standaardvorm.composition_source(source, pathlib.Path(json_path).as_posix())
        elif tijdlijn.is_timeline(data):
            # the sounds are the file's own patches: "patch:<the file's full path>:<channel>"
            source = tijdlijn.read(json_path)
            warnings = list(source["warnings"])
            source_text = tijdlijn.composition_source(source, module_name, pathlib.Path(json_path).as_posix())
        else:
            source = json_bron.read(json_path)
            warnings = list(source.warnings)
            source_text = tracker.composition_source(source, module_name, tracker.default_title(source))
    except KeyError as error:
        raise ValueError(f"{json_path}: de compositie kan zo niet gebruikt worden: {error} ontbreekt")
    with tempfile.TemporaryDirectory() as folder:
        with open(os.path.join(folder, module_name + ".py"), "w", encoding="utf-8") as composition_file:
            composition_file.write(source_text)
        sys.path.insert(0, folder)
        importlib.invalidate_caches()
        try:
            score = score_module.load(module_name)
        except ValueError as error:
            # e.g. a channel of a timeline that plays without a patch in 'hardware_patches'
            raise ValueError(f"{json_path}: de compositie kan zo niet gespeeld worden: {error}")
        finally:
            sys.path.remove(folder)
            sys.modules.pop(module_name, None)
    piece = dataclasses.replace(derive.intro(score), name=piece_name)
    if piece.tracker:
        # played from the file where it is, not from a copy in composities/ (a full path)
        piece = dataclasses.replace(piece, tracker=json_path)
    return piece, warnings


def output_problem(ogg_path: str) -> str:
    """What is wrong with the output path (Dutch), or ""."""
    if not ogg_path.lower().endswith(".ogg"):
        return f"{ogg_path}: de uitvoer moet op .ogg eindigen"
    folder = os.path.dirname(os.path.abspath(ogg_path))
    if not os.path.isdir(folder):
        return f"{folder}: de map voor de uitvoer bestaat niet"
    if os.path.isdir(ogg_path):
        return f"{ogg_path}: is een map"
    if os.path.realpath(folder) == os.path.realpath(MUSIC_FOLDER):
        return (f"{folder}: daar staat de muziek van het spel; kies een andere plek "
                "(een compositie in het spel zetten: de skill muziek-compositie, docs/MUZIEK.md)")
    return ""


def main(arguments: list = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("json", help="the composition in JSON")
    parser.add_argument("ogg", help="the OGG file to write")
    options = parser.parse_args(arguments)
    wrong = output_problem(options.ogg)
    if wrong:
        print("json_naar_ogg: " + wrong, file=sys.stderr)
        return 1
    try:
        import soundfile  # noqa: F401 (the encoder megadrive.write_ogg uses)
    except ImportError:
        print("json_naar_ogg: de OGG-encoder ontbreekt (het Python-pakket soundfile); start via "
              "tools/muziek/json_naar_ogg.sh (of .ps1), dat haalt het met uv op", file=sys.stderr)
        return 1
    ogg_path = os.path.abspath(options.ogg)
    try:
        piece, warnings = piece_as_written(options.json, os.path.basename(ogg_path)[:-len(".ogg")])
    except (ValueError, OSError) as error:
        print(f"json_naar_ogg: {error}", file=sys.stderr)
        return 1
    print(f"compositie: {options.json} ({piece.tempo:g} BPM, {len(piece.bars)} maten)")
    for warning in warnings:
        print("LET OP: " + warning)
    mixer.write(piece, os.path.dirname(ogg_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
