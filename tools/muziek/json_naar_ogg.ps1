# Renders one composition in JSON (docs/MUZIEK_JSON.md) to one OGG file, to listen to it: the
# composition as written, played once with the Mega Drive sound of the game's music
# (tools/muziek/json_naar_ogg.py); Windows PowerShell, the same as tools/muziek/json_naar_ogg.sh.
# Nothing of the game changes: no derived pieces, nothing in assets/audio/muziek/ or
# tools/muziek/composities/.
# Usage: tools\muziek\json_naar_ogg.ps1 <compositie.json> <uitvoer.ogg>
#   e.g. tools\muziek\json_naar_ogg.ps1 data\muziek\street_viper_92.json $HOME\Desktop\street_viper_92.ogg
# Needs uv (https://docs.astral.sh/uv/).
$called_from = (Get-Location).Path
Set-Location $PSScriptRoot
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
	[Console]::Error.WriteLine('json_naar_ogg.ps1: uv niet gevonden (installeren: https://docs.astral.sh/uv/)')
	exit 127
}
if ($args.Count -ne 2) {
	[Console]::Error.WriteLine('gebruik: tools\muziek\json_naar_ogg.ps1 <compositie.json> <uitvoer.ogg>')
	exit 2
}
# the files as given from where the script was called: their full paths
function Resolve-FromCaller([string]$Path) {
	if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
	return (Join-Path $called_from $Path)
}
$json_file = Resolve-FromCaller ([string]$args[0])
$ogg_file = Resolve-FromCaller ([string]$args[1])
# python: "python" on Windows (uv provides it), no stdin
$null | & uv run --quiet --with soundfile --with numpy python json_naar_ogg.py $json_file $ogg_file | Out-Host
exit $LASTEXITCODE
