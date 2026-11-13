# Makes the music of the game from the base compositions of composities/actief.py (tools/muziek/build.py,
# docs/MUZIEK.md); Windows PowerShell, the same as tools/muziek/render.sh.
# Usage: tools\muziek\render.ps1                          (everything, into assets/audio/muziek/)
#        tools\muziek\render.ps1 zwervr_intro spel_loop   (only these)
#        tools\muziek\render.ps1 --uit <folder>           (somewhere else, to listen first)
#        tools\muziek\render.ps1 --controle               (check what is in assets/audio/muziek/)
#        tools\muziek\render.ps1 --test                   (the unit tests of the music tools, test_muziek.py)
#        tools\muziek\render.ps1 --json <file> [naam]     (a composition in JSON to composities/<naam>.py,
#                                                          json_bron.py, docs/MUZIEK_JSON.md: the preferred source)
#        tools\muziek\render.ps1 --tracker <file> [naam]  (a tracker page (HTML) the same way, tracker.py)
# Needs uv (https://docs.astral.sh/uv/), and node for --tracker.
$called_from = (Get-Location).Path
Set-Location $PSScriptRoot
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
	[Console]::Error.WriteLine('render.ps1: uv not found (install it: https://docs.astral.sh/uv/)')
	exit 127
}
# python: "python" on Windows (uv provides it), no stdin
function Invoke-Python {
	# its output to the screen (as function output, `exit (Invoke-Python ...)` would swallow it)
	$null | & uv run --quiet --with soundfile --with numpy python @args | Out-Host
	return $LASTEXITCODE
}
# a file given from where the script was called: its full path
function Resolve-Source([object[]]$Arguments) {
	if ($Arguments.Count -gt 0 -and -not [System.IO.Path]::IsPathRooted([string]$Arguments[0])) {
		$Arguments[0] = Join-Path $called_from ([string]$Arguments[0])
	}
	return $Arguments
}
$first = ''
if ($args.Count -gt 0) { $first = [string]$args[0] }
$rest = @()
if ($args.Count -gt 1) { $rest = @($args[1..($args.Count - 1)]) }
switch ($first) {
	'--test' { exit (Invoke-Python test_muziek.py) }
	'--controle' { exit (Invoke-Python check.py @rest) }
	'--json' { $rest = @(Resolve-Source $rest); exit (Invoke-Python json_bron.py @rest) }
	'--tracker' { $rest = @(Resolve-Source $rest); exit (Invoke-Python tracker.py @rest) }
	default { exit (Invoke-Python build.py @args) }
}
