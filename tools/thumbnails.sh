#!/bin/sh
# Maakt de thumbnails (previews) van alle tiles in de MeshLibraries, zodat de editor bij
# het openen van een scene niets meer hoeft te doen ("Creating mesh previews").
# Rendert in een klein venster rechtsonder (dat is nodig om te renderen); doe het liefst
# met de editor dicht, die schrijft dezelfde libraries.
#
#   tools/thumbnails.sh                 alleen tiles waarvan de thumbnail verouderd is of ontbreekt
#   tools/thumbnails.sh alles           alle tiles opnieuw
#   tools/thumbnails.sh bouwen          eerst de MeshLibraries bijwerken (tools/build/build_libraries.gd)
#
# "bouwen" en "alles" mogen samen: tools/thumbnails.sh bouwen alles
cd "$(dirname "$0")/.." || exit 1
build=false
all=""
for argument in "$@"; do
	case "$argument" in
		bouwen) build=true ;;
		alles) all="all" ;;
		*) echo "thumbnails.sh: onbekend argument '$argument' (bouwen, alles)" >&2; exit 2 ;;
	esac
done
if [ "$build" = true ]; then
	GODOT_TIMEOUT="${GODOT_TIMEOUT:-1800}" tools/godot.sh --headless --script tools/build/build_libraries.gd || exit $?
fi
GODOT_TIMEOUT="${GODOT_TIMEOUT:-1200}" exec tools/godot.sh --script tools/build/build_previews.gd -- $all
