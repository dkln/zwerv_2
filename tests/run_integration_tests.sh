#!/bin/sh
# Runs the integration tests (tests/integration/<category>/test_*.gd: suites that extend
# tests/integration/support/town_test.gd, run by tests/run_integration_tests.gd: the town
# started once for all suites that want the same world, every test_ function a test; the
# unit tests are tests/unit/, tests/run_unit_tests.gd) headless and fast:
# game time runs on as fast as the frames can be made, not with the clock. `--fixed-fps`
# gives every frame the same step of game time (1/FPS s, also for the physics), whatever it
# took to make; headless a frame takes far less than that, so a wait of 10 s game time (a
# timer, a chase, a train) passes in a fraction of it. Engine.time_scale is left alone (the
# game sets it itself: slow motion; some tests set it too). A time limit per run as
# tools/godot.sh (TEST_TIMEOUT, default 300 s).
# The exit code comes from the line "CHECK_KLAAR ok" / "CHECK_KLAAR fout" of the run
# (Common.finish): shutting down a run with the whole town can hang in the engine, and then
# the run ends the process itself, which says nothing about how the tests went.
#
#   tests/run_integration_tests.sh throw_out            one suite (tests/integration/interiors/test_throw_out.gd)
#   tests/run_integration_tests.sh test_traffic         the same, for a suite named as its category
#   tests/run_integration_tests.sh traffic_run -- 300   arguments after -- go to the suite
#   tests/run_integration_tests.sh interiors            a whole category (without its own-process suites)
#   tests/run_integration_tests.sh alle                 every category and every own-process suite, and a summary
#   TEST_FPS=30 tests/run_integration_tests.sh station  bigger steps (faster still, coarser physics)
cd "$(dirname "$0")/.." || exit 1
name="$1"
[ -n "$name" ] || { echo "usage: tests/run_integration_tests.sh <name>|<category>|alle [-- args]" >&2; exit 2; }
shift
[ "$1" = "--" ] && shift

# one run of the runner for `$1` (a suite, a category): its output, and 0 (it said ok),
# 1 (it said fout) or 3 (it never said)
run_one() {
	log="$(mktemp -t integratie)"
	GODOT_TIMEOUT="${TEST_TIMEOUT:-300}" tools/godot.sh --headless --fixed-fps "${TEST_FPS:-60}" --script tests/run_integration_tests.gd -- "$@" 2>&1 | tee "$log"
	if grep -q "^CHECK_KLAAR ok" "$log"; then
		result=0
	elif grep -q "^CHECK_KLAAR fout" "$log"; then
		result=1
	else
		result=3
	fi
	rm -f "$log"
	return $result
}

# only the lines that say how the tests went
summary() {
	grep -E "^(ok |FOUT |=== |integratietests)"
}

if [ "$name" = "alle" ]; then
	failed=""
	# per category one run: its suites share the town
	output="$(mktemp -t integratie_alle)"
	for folder in tests/integration/*/; do
		category="$(basename "$folder")"
		[ "$category" = "support" ] && continue
		echo "=== $category"
		run_one "$category" > "$output" 2>&1 || failed="$failed $category"
		summary < "$output"
	done
	rm -f "$output"
	# the suites that want a run of their own
	for script in $(grep -l '"own_process": true' tests/integration/*/test_*.gd); do
		suite="$(basename "$script" .gd)"
		echo "=== $suite (eigen proces)"
		if ! run_one "$suite" > /dev/null; then
			failed="$failed $suite"
			echo "FOUT  $suite"
		else
			echo "ok    $suite"
		fi
	done
	if [ -z "$failed" ]; then
		echo "integratietests: alles ok"
		exit 0
	fi
	echo "integratietests mislukt:$failed"
	exit 1
fi
# a whole category: its suites in one run
if [ -d "tests/integration/$name" ] && [ "$name" != "support" ]; then
	run_one "$name"
	exit $?
fi
name="${name%.gd}"
name="${name#test_}"
script="$(ls tests/integration/*/test_${name}.gd 2>/dev/null | head -1)"
[ -n "$script" ] && [ -f "$script" ] || { echo "run_integration_tests.sh: no test_${name}.gd" >&2; exit 2; }
run_one "test_${name}" "$@"
