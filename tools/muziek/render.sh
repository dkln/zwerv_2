#!/bin/sh
# Makes the music of the game from the active composition (tools/muziek/build.py, docs/MUZIEK.md).
# Usage: tools/muziek/render.sh                          (everything, into assets/audio/muziek/)
#        tools/muziek/render.sh zwervr_intro spel_loop   (only these)
#        tools/muziek/render.sh --uit <folder>           (somewhere else, to listen first)
#        tools/muziek/render.sh --controle               (check what is in assets/audio/muziek/)
#        tools/muziek/render.sh --test                   (the unit tests of the music tools, test_muziek.py)
#        tools/muziek/render.sh --json <file> [naam]     (a composition in JSON to composities/<naam>.py,
#                                                         json_bron.py, docs/MUZIEK_JSON.md: the preferred source;
#                                                         --toon only shown, --meet [wav] measured)
#        tools/muziek/render.sh --tracker <file> [naam]  (a tracker page (HTML) the same way, tracker.py)
#        tools/muziek/render.sh --vgm <file> [naam]      (a VGM file to composities/<naam>.py, vgm.py;
#                                                         with --toon only shown, with --vergelijk compared)
CALLED_FROM="$(pwd)"
cd "$(dirname "$0")" || exit 1
if [ "$1" = "--test" ]; then
	exec uv run --quiet --with soundfile --with numpy python3 test_muziek.py < /dev/null
fi
if [ "$1" = "--json" ] || [ "$1" = "--tracker" ]; then
	# a composition in JSON (json_bron.py: docs/MUZIEK_JSON.md) or a tracker page (tracker.py)
	reader="json_bron.py"
	[ "$1" = "--tracker" ] && reader="tracker.py"
	shift
	case "$1" in
		/*|"") ;;
		*) source_file="$CALLED_FROM/$1"; shift; set -- "$source_file" "$@" ;;
	esac
	exec uv run --quiet --with soundfile --with numpy python3 "$reader" "$@" < /dev/null
fi
if [ "$1" = "--vgm" ]; then
	shift
	# (the file's path as given from where the script was called)
	case "$1" in
		/*|"") ;;
		*) vgm_file="$CALLED_FROM/$1"; shift; set -- "$vgm_file" "$@" ;;
	esac
	exec uv run --quiet --with soundfile --with numpy python3 vgm.py "$@" < /dev/null
fi
if [ "$1" = "--controle" ]; then
	shift
	exec uv run --quiet --with soundfile --with numpy python3 check.py "$@" < /dev/null
fi
exec uv run --quiet --with soundfile --with numpy python3 build.py "$@" < /dev/null
