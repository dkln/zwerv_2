#!/bin/sh
# Makes the music of the game from the active composition (tools/muziek/build.py, docs/MUZIEK.md).
# Usage: tools/muziek/render.sh                          (everything, into assets/audio/muziek/)
#        tools/muziek/render.sh zwervr_intro spel_loop   (only these)
#        tools/muziek/render.sh --uit <folder>           (somewhere else, to listen first)
#        tools/muziek/render.sh --controle               (check what is in assets/audio/muziek/)
#        tools/muziek/render.sh --test                   (the unit tests of the music tools, test_muziek.py)
cd "$(dirname "$0")" || exit 1
if [ "$1" = "--test" ]; then
	exec uv run --quiet --with soundfile --with numpy python3 test_muziek.py < /dev/null
fi
if [ "$1" = "--controle" ]; then
	shift
	exec uv run --quiet --with soundfile --with numpy python3 check.py "$@" < /dev/null
fi
exec uv run --quiet --with soundfile --with numpy python3 build.py "$@" < /dev/null
