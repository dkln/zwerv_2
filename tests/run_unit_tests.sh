#!/bin/sh
# Runs the unit tests (tests/unit/<category>/test_*.gd, tests/run_unit_tests.gd), headless.
# (Windows: tests\run_unit_tests.ps1.)
#
#   tests/run_unit_tests.sh               every test
#   tests/run_unit_tests.sh babble        the files with "babble" in their name
#   tests/run_unit_tests.sh audio         a whole category (its folder)
cd "$(dirname "$0")/.." || exit 1
if [ $# -gt 0 ]; then
	GODOT_TIMEOUT="${GODOT_TIMEOUT:-300}" exec tools/godot.sh --headless --script tests/run_unit_tests.gd -- "$@"
fi
GODOT_TIMEOUT="${GODOT_TIMEOUT:-300}" exec tools/godot.sh --headless --script tests/run_unit_tests.gd
