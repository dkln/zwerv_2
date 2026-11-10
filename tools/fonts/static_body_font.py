"""Static weights of JetBrains Mono (assets/fonts/JetBrainsMono.ttf, a variable font) with
the overlapping contours merged.

Godot draws the UI fonts as MSDF (multichannel signed distance fields, see the .import
files), and MSDF cannot handle contours that overlap: in the variable JetBrains Mono the "8"
is two overlapping loops, which came out as a bright smear ("de 800 meter" in Martin's story).
A static instance with the overlaps removed draws clean. UiStyle.weighted (scripts/ui/ui_style.gd)
uses these files for the weights it has (BODY_WEIGHTS) and the variable font for the rest.

usage: uv run --with fonttools --with skia-pathops python tools/fonts/static_body_font.py
"""

from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.ttLib.removeOverlaps import removeOverlaps
from fontTools.varLib.instancer import instantiateVariableFont

FONTS = Path(__file__).resolve().parents[2] / "assets" / "fonts"
SOURCE = FONTS / "JetBrainsMono.ttf"
# weight -> the file name (keep in step with BODY_WEIGHTS in scripts/ui/ui_style.gd)
WEIGHTS = {400: "JetBrainsMono-Regular.ttf", 600: "JetBrainsMono-SemiBold.ttf"}


def main() -> None:
    for weight, file_name in WEIGHTS.items():
        font = instantiateVariableFont(TTFont(SOURCE), {"wght": weight})
        removeOverlaps(font)
        font.save(FONTS / file_name)
        print(f"{file_name}: wght {weight}, overlaps removed")


if __name__ == "__main__":
    main()
