#!/bin/sh
# Renders the Mega Drive style music in tools/megadrive/ to assets/audio/muziek/*.ogg
# and the traffic sound effects to assets/audio/geluiden/*.ogg.
# Usage: tools/megadrive/render.sh                       (everything)
#        tools/megadrive/render.sh gevecht handelaar     (only these pieces)
#        tools/megadrive/render.sh deuntjes dood         (one stinger: kaart_start, gewonnen,
#                                                         level_omhoog, verloren, dood)
#        tools/megadrive/render.sh geluiden             (the traffic sound effects, see geluiden.py;
#                                                         or some: render.sh geluiden tram_bel)
# Pieces: stad_centrum stad_torens stad_groen stad_woonwijk stad_industrie nachtstad_menu karakterkeuze zwervr_intro gevecht handelaar deuntjes geluiden
cd "$(dirname "$0")" || exit 1
all="stad_centrum stad_torens stad_groen stad_woonwijk stad_industrie nachtstad_menu karakterkeuze zwervr_intro gevecht handelaar deuntjes geluiden"
run() {
	uv run --quiet --with soundfile --with numpy python3 "$@" < /dev/null || exit 1
}
if [ "$1" = "deuntjes" ] || [ "$1" = "geluiden" ]; then
	piece="$1"
	shift
	run "$piece.py" "$@"
	exit 0
fi
for song in ${*:-$all}; do
	run "$song.py"
done
