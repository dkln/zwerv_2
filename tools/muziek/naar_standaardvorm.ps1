# Brings a composition in JSON to the standard form (docs/MUZIEK_JSON.md, "De standaardvorm"): the
# one structure every file in data/muziek/ has (tools/muziek/naar_standaardvorm.py); Windows
# PowerShell, the same as tools/muziek/naar_standaardvorm.sh.
# Usage: tools\muziek\naar_standaardvorm.ps1 <bestand.json>              (in place; the file as it was is
#                                                                         kept in origineel\ next to it)
#        tools\muziek\naar_standaardvorm.ps1 <bestand.json> <uit.json>   (written somewhere else)
#        tools\muziek\naar_standaardvorm.ps1 --controle <bestand.json>... (only: is it in the standard form?)
# Needs uv (https://docs.astral.sh/uv/).
$called_from = (Get-Location).Path
Set-Location $PSScriptRoot
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
	[Console]::Error.WriteLine('naar_standaardvorm.ps1: uv niet gevonden (installeren: https://docs.astral.sh/uv/)')
	exit 127
}
if ($args.Count -lt 1) {
	[Console]::Error.WriteLine('gebruik: tools\muziek\naar_standaardvorm.ps1 [--controle] <bestand.json> [<uit.json>]')
	exit 2
}
# the files as given from where the script was called: their full paths
$resolved = @()
foreach ($argument in $args) {
	$text = [string]$argument
	if ($text.StartsWith('--') -or [System.IO.Path]::IsPathRooted($text)) { $resolved += $text }
	else { $resolved += (Join-Path $called_from $text) }
}
# python: "python" on Windows (uv provides it), no stdin
$null | & uv run --quiet --with soundfile --with numpy python naar_standaardvorm.py @resolved | Out-Host
exit $LASTEXITCODE
