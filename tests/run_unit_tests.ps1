# Runs the unit tests (tests/unit/<category>/test_*.gd, tests/run_unit_tests.gd), headless
# (Windows PowerShell; the same as tests/run_unit_tests.sh).
#
#   tests\run_unit_tests.ps1               every test
#   tests\run_unit_tests.ps1 babble        the files with "babble" in their name
#   tests\run_unit_tests.ps1 audio         a whole category (its folder)
$root = Split-Path -Parent $PSScriptRoot
if (-not $env:GODOT_TIMEOUT) { $env:GODOT_TIMEOUT = 300 }
if ($args.Count -gt 0) {
	& "$root\tools\godot.ps1" --headless --script tests/run_unit_tests.gd '--' @args
} else {
	& "$root\tools\godot.ps1" --headless --script tests/run_unit_tests.gd
}
exit $LASTEXITCODE
