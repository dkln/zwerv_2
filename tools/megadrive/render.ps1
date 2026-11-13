# Renders the sound effects and voices in Mega Drive style to assets/audio/geluiden/ and
# assets/audio/kreten/ (docs/GELUIDEN.md); Windows PowerShell, the same as tools/megadrive/render.sh.
# Usage: tools\megadrive\render.ps1 geluiden             (all sound effects, see geluiden.py;
#                                                         or some: render.ps1 geluiden tram_bel)
#        tools\megadrive\render.ps1 stemmen              (the cries of pain, see stemmen.py)
#        tools\megadrive\render.ps1                      (both)
# Needs uv (https://docs.astral.sh/uv/).
Set-Location $PSScriptRoot
function Invoke-Python {
	$null | & uv run --quiet --with soundfile --with numpy python @args
	if ($LASTEXITCODE -ne 0) { exit 1 }
}
if ($args.Count -gt 0 -and ($args[0] -eq 'geluiden' -or $args[0] -eq 'stemmen')) {
	$rest = @()
	if ($args.Count -gt 1) { $rest = @($args[1..($args.Count - 1)]) }
	Invoke-Python "$($args[0]).py" @rest
	exit 0
}
if ($args.Count -gt 0) {
	[Console]::Error.WriteLine("unknown: $($args[0]) (geluiden or stemmen)")
	exit 1
}
Invoke-Python geluiden.py
Invoke-Python stemmen.py
