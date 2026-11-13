# Runs the integration tests (Windows PowerShell; the same as tests/run_integration_tests.sh):
# tests/integration/<category>/test_*.gd, the whole town loaded and a scenario played through.
# The suites that extend tests/integration/support/town_test.gd share one town in one run
# (tests/run_integration_tests.gd), the older ones each start their own. Headless and fast:
# `--fixed-fps` gives every frame the same step of game time, whatever it took to make, so
# game time runs faster than the clock. A time limit per run ($env:TEST_TIMEOUT, default 300 s).
# The exit code comes from the line "CHECK_KLAAR ok" / "CHECK_KLAAR fout" of the run
# (Common.finish): shutting down a run with the whole town can hang in the engine, and then
# the run ends the process itself, which says nothing about how the tests went.
#
#   tests\run_integration_tests.ps1 throw_out            tests/integration/interiors/test_throw_out.gd
#   tests\run_integration_tests.ps1 station -- 12        arguments after -- go to the test
#   tests\run_integration_tests.ps1 interiors            a whole category (its suites of the shared town)
#   tests\run_integration_tests.ps1 alle                 every test, and a summary
#   $env:TEST_FPS = 30; tests\run_integration_tests.ps1 station   bigger steps (faster still, coarser physics)
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if ($args.Count -eq 0) {
	[Console]::Error.WriteLine('usage: tests\run_integration_tests.ps1 <name>|<category>|alle [-- args]')
	exit 2
}
$name = [string]$args[0]
$rest = @()
if ($args.Count -gt 1) { $rest = $args[1..($args.Count - 1)] }
$fps = 60
if ($env:TEST_FPS) { $fps = [int]$env:TEST_FPS }
$env:GODOT_TIMEOUT = 300
if ($env:TEST_TIMEOUT) { $env:GODOT_TIMEOUT = [int]$env:TEST_TIMEOUT }

# one run: its output shown (unless $Quiet), and 0 (it said ok), 1 (it said fout) or 3 (it never said)
function Invoke-Run([string]$Script, [object[]]$Arguments, [bool]$Quiet) {
	$said = 3
	& "$root\tools\godot.ps1" --headless --fixed-fps $fps --script $Script @Arguments | ForEach-Object {
		$line = [string]$_
		if (-not $Quiet) { Write-Host $line }
		if ($line.StartsWith('CHECK_KLAAR ok')) { $said = 0 }
		elseif ($line.StartsWith('CHECK_KLAAR fout')) { $said = 1 }
	}
	return $said
}

# a suite of the shared town (it extends tests/integration/support/town_test.gd)?
function Test-SharesTown([string]$Path) {
	return [bool](Select-String -Path $Path -Pattern 'support/town_test.gd' -Quiet)
}

if ($name -eq 'alle') {
	$failed = @()
	Write-Host '=== de suites met een gedeelde stad'
	if ((Invoke-Run 'tests/run_integration_tests.gd' @('--', 'alle') $false) -ne 0) { $failed += 'gedeelde-stad' }
	foreach ($file in (Get-ChildItem -Path 'tests/integration' -Recurse -Filter 'test_*.gd' | Sort-Object FullName)) {
		if ($file.Directory.Name -eq 'support' -or (Test-SharesTown $file.FullName)) { continue }
		$script = 'tests/integration/' + $file.Directory.Name + '/' + $file.Name
		Write-Host "=== $script"
		if ((Invoke-Run $script $rest $true) -ne 0) { $failed += $file.BaseName }
	}
	if ($failed.Count -eq 0) {
		Write-Host 'integratietests: alles ok'
		exit 0
	}
	Write-Host ('integratietests mislukt: ' + ($failed -join ' '))
	exit 1
}
# a whole category: its suites of the shared town in one run
if (Test-Path "tests/integration/$name" -PathType Container) {
	exit (Invoke-Run 'tests/run_integration_tests.gd' @('--', $name) $false)
}
$name = $name -replace '\.gd$', '' -replace '^test_', '' -replace '_test$', ''
$found = Get-ChildItem -Path 'tests/integration' -Recurse -Filter "test_$name.gd" | Select-Object -First 1
if (-not $found) {
	[Console]::Error.WriteLine("run_integration_tests.ps1: no test_$name.gd")
	exit 2
}
if (Test-SharesTown $found.FullName) {
	exit (Invoke-Run 'tests/run_integration_tests.gd' @('--', $name) $false)
}
exit (Invoke-Run ('tests/integration/' + $found.Directory.Name + '/' + $found.Name) $rest $false)
