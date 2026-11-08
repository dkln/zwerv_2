#!/bin/sh
# Bakt de samengevoegde meshes van de kaarten vooraf in de cache (user://merged), zodat het
# spel bij het starten alleen hoeft te laden. Draai dit na het bouwen van de stad
# (tools/build/build_city.gd), na het opnieuw opbouwen van de tiles, of na een wijziging aan
# layer_baker.gd. Zonder venster (headless); de editor mag openblijven.
#
#   tools/bake.sh                       alle kaarten met een DetailNiveau (scenes/*.tscn)
#   tools/bake.sh opnieuw               eerst de cache van die kaarten leeg: alles opnieuw
#   tools/bake.sh scenes/stad.tscn      alleen deze kaart
#
# Een kaart waarvan de cache al klopt wordt overgeslagen (snel). Cachebestanden van
# kaarten die niet meer bestaan worden opgeruimd.
cd "$(dirname "$0")/.." || exit 1
GODOT_TIMEOUT="${GODOT_TIMEOUT:-3600}" exec tools/godot.sh --headless --script tools/build/bake_maps.gd -- "$@"
