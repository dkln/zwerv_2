#!/bin/sh
# Runs Godot on this project with a time limit and without stdin, so a stuck run (a
# script error before quit(), a dialog, a hanging import) can never block the terminal:
#
#   tools/godot.sh --headless --script tools/build_example_city.gd
#   GODOT_TIMEOUT=1200 tools/godot.sh --headless --import
#
# GODOT: the Godot binary (default: the macOS app). GODOT_TIMEOUT: seconds before the
# run is stopped (default 600); the exit code is then 124 and a message says so.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
LIMIT="${GODOT_TIMEOUT:-600}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if command -v timeout >/dev/null 2>&1; then
	timeout --kill-after=10 "$LIMIT" "$GODOT" --path "$ROOT" "$@" < /dev/null
else
	# no coreutils timeout: perl's alarm does the same (the signal ends Godot)
	perl -e 'alarm shift; exec @ARGV or die "cannot run $ARGV[0]\n"' "$LIMIT" "$GODOT" --path "$ROOT" "$@" < /dev/null
fi
status=$?
if [ $status -eq 124 ] || [ $status -eq 142 ]; then
	echo "godot.sh: Godot stopped after $LIMIT s (time limit)" >&2
fi
exit $status
