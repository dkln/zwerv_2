#!/bin/sh
# Reimports, headless, the tiles whose side files (their .tile.json, .lod.tile.json, .lod.gox,
# or the colour table assets/tiles/materialen.json) are newer than their imported mesh, and
# then rebuilds the MeshLibraries. This is the same check the editor plugin does on start
# (addons/vox_tiles/plugin.gd, _tiles_with_newer_side_files), done beforehand, so opening the
# editor does not start a long reimport.
#
# Godot only watches the model file itself, so for these tiles it sees nothing to do; removing
# the imported mesh (and its .md5) makes it import them again.
#
# Usage (with the editor closed: a headless import next to an open editor crashes it):
#   tools/build/reimport_stale.sh            reimport stale tiles, rebuild the libraries
#   tools/build/reimport_stale.sh --list     only list the stale tiles
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

if pgrep -qx Godot; then
	echo "reimport_stale: close Godot first (editor or another run)" >&2
	exit 1
fi

colour_table="assets/tiles/materialen.json"
stale_list="$(mktemp)"
echo "reimport_stale: tiles nakijken ..."
find assets/tiles -name '*.gox' ! -name '*.lod.gox' -o -name '*.vox' ! -name '*.lod.vox' | while read -r model; do
	import_file="$model.import"
	[ -f "$import_file" ] || continue
	imported_mesh="$(sed -n 's/^path="res:\/\/\(.*\)"/\1/p' "$import_file")"
	if [ ! -f "$imported_mesh" ]; then
		echo "$model	$imported_mesh" >> "$stale_list"
		continue
	fi
	mesh_time="$(stat -f %m "$imported_mesh")"
	base="${model%.*}"
	for side_file in "$base.tile.json" "$base.lod.tile.json" "$base.lod.gox" "$base.lod.vox" "$colour_table"; do
		if [ -f "$side_file" ] && [ "$(stat -f %m "$side_file")" -gt "$mesh_time" ]; then
			echo "$model	$imported_mesh" >> "$stale_list"
			break
		fi
	done
done

stale_count="$(wc -l < "$stale_list" | tr -d ' ')"
echo "reimport_stale: $stale_count verouderde tiles"
if [ "$1" = "--list" ]; then
	cut -f1 "$stale_list"
	rm -f "$stale_list"
	exit 0
fi
if [ "$stale_count" -eq 0 ]; then
	rm -f "$stale_list"
	exit 0
fi

cut -f2 "$stale_list" | while read -r imported_mesh; do
	[ -n "$imported_mesh" ] && rm -f "$imported_mesh" "${imported_mesh%.*}.md5"
done
rm -f "$stale_list"

echo "[ stap 1/2 ] $stale_count tiles importeren"
GODOT_TIMEOUT="${GODOT_TIMEOUT:-3600}" tools/godot.sh --headless --import || exit $?
echo "[ stap 2/2 ] bibliotheken bijwerken"
GODOT_TIMEOUT="${GODOT_TIMEOUT:-3600}" tools/godot.sh --headless --script tools/build/build_libraries.gd
