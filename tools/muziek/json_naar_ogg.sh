#!/bin/sh
# Renders one composition in JSON (docs/MUZIEK_JSON.md) to one OGG file, to listen to it: the
# composition as written, played once with the Mega Drive sound of the game's music
# (tools/muziek/json_naar_ogg.py). Nothing of the game changes: no derived pieces, nothing in
# assets/audio/muziek/ or tools/muziek/composities/.
# Usage: tools/muziek/json_naar_ogg.sh <compositie.json> <uitvoer.ogg>
#   e.g. tools/muziek/json_naar_ogg.sh data/muziek/street_viper_92.json ~/Desktop/street_viper_92.ogg
# Needs uv (https://docs.astral.sh/uv/).
CALLED_FROM="$(pwd)"
cd "$(dirname "$0")" || exit 1
if ! command -v uv > /dev/null 2>&1; then
	echo "json_naar_ogg.sh: uv niet gevonden (installeren: https://docs.astral.sh/uv/)" >&2
	exit 127
fi
if [ "$#" -ne 2 ]; then
	echo "gebruik: tools/muziek/json_naar_ogg.sh <compositie.json> <uitvoer.ogg>" >&2
	exit 2
fi
# the files as given from where the script was called: their full paths
json_file="$1"
ogg_file="$2"
case "$json_file" in /*) ;; *) json_file="$CALLED_FROM/$json_file" ;; esac
case "$ogg_file" in /*) ;; *) ogg_file="$CALLED_FROM/$ogg_file" ;; esac
exec uv run --quiet --with soundfile --with numpy python3 json_naar_ogg.py "$json_file" "$ogg_file" < /dev/null
