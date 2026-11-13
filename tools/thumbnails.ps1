# Maakt de thumbnails (previews) van alle tiles in de MeshLibraries (Windows PowerShell;
# hetzelfde als tools/thumbnails.sh). Rendert in een klein venster; doe het liefst met de
# editor dicht, die schrijft dezelfde libraries.
#
#   tools\thumbnails.ps1                 alleen tiles waarvan de thumbnail verouderd is of ontbreekt
#   tools\thumbnails.ps1 alles           alle tiles opnieuw
#   tools\thumbnails.ps1 bouwen          eerst de MeshLibraries bijwerken (tools/build/build_libraries.gd)
$build = $false
$all = @()
foreach ($argument in $args) {
	switch ($argument) {
		'bouwen' { $build = $true }
		'alles' { $all = @('all') }
		default {
			[Console]::Error.WriteLine("thumbnails.ps1: onbekend argument '$argument' (bouwen, alles)")
			exit 2
		}
	}
}
$limit_given = [bool]$env:GODOT_TIMEOUT
if ($build) {
	Write-Output '[ stap 1/2 ] bibliotheken bijwerken'
	if (-not $limit_given) { $env:GODOT_TIMEOUT = 1800 }
	& "$PSScriptRoot\godot.ps1" --headless --script tools/build/build_libraries.gd
	if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
	Write-Output '[ stap 2/2 ] thumbnails maken'
}
if (-not $limit_given) { $env:GODOT_TIMEOUT = 1200 }
& "$PSScriptRoot\godot.ps1" --script tools/build/build_previews.gd -- @all
exit $LASTEXITCODE
