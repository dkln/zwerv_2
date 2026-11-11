#!/bin/sh
# Renders the sound effects and voices in Mega Drive style to assets/audio/geluiden/ and
# assets/audio/kreten/ (docs/GELUIDEN.md). The music generators were removed (Nov. 2026).
# Usage: tools/megadrive/render.sh geluiden             (all sound effects, see geluiden.py;
#                                                        or some: render.sh geluiden tram_bel)
#        tools/megadrive/render.sh stemmen              (the cries of pain, see stemmen.py)
#        tools/megadrive/render.sh                      (both)
cd "$(dirname "$0")" || exit 1
run() {
	uv run --quiet --with soundfile --with numpy python3 "$@" < /dev/null || exit 1
}
if [ "$1" = "geluiden" ] || [ "$1" = "stemmen" ]; then
	piece="$1"
	shift
	run "$piece.py" "$@"
	exit 0
fi
if [ -n "$1" ]; then
	echo "unknown: $1 (geluiden or stemmen)" >&2
	exit 1
fi
run geluiden.py
run stemmen.py
