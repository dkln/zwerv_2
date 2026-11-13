# Reimports, headless, the tiles whose side files (their .tile.json, .lod.tile.json, .lod.gox,
# or the colour table assets/tiles/materialen.json) are newer than their imported mesh, and
# then rebuilds the MeshLibraries (Windows PowerShell; the same as tools/build/reimport_stale.sh).
#
# Usage (with the editor closed: a headless import next to an open editor crashes it):
#   tools\build\reimport_stale.ps1            reimport stale tiles, rebuild the libraries
#   tools\build\reimport_stale.ps1 --list     only list the stale tiles
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
if (Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue) {
	[Console]::Error.WriteLine('reimport_stale: close Godot first (editor or another run)')
	exit 1
}
$colour_table = 'assets/tiles/materialen.json'
$stale = @()
Write-Output 'reimport_stale: tiles nakijken ...'
$models = Get-ChildItem -Path 'assets/tiles' -Recurse -File | Where-Object {
	($_.Name -like '*.gox' -and $_.Name -notlike '*.lod.gox') -or ($_.Name -like '*.vox' -and $_.Name -notlike '*.lod.vox')
}
foreach ($model in $models) {
	$import_file = $model.FullName + '.import'
	if (-not (Test-Path $import_file)) { continue }
	$path_line = Select-String -Path $import_file -Pattern '^path="res://(.*)"' | Select-Object -First 1
	if (-not $path_line) { continue }
	$imported_mesh = $path_line.Matches[0].Groups[1].Value
	if (-not (Test-Path $imported_mesh)) {
		$stale += [pscustomobject]@{ Model = $model.FullName; Mesh = $imported_mesh }
		continue
	}
	$mesh_time = (Get-Item $imported_mesh).LastWriteTimeUtc
	$base = $model.FullName.Substring(0, $model.FullName.Length - $model.Extension.Length)
	foreach ($side_file in @("$base.tile.json", "$base.lod.tile.json", "$base.lod.gox", "$base.lod.vox", $colour_table)) {
		if ((Test-Path $side_file) -and ((Get-Item $side_file).LastWriteTimeUtc -gt $mesh_time)) {
			$stale += [pscustomobject]@{ Model = $model.FullName; Mesh = $imported_mesh }
			break
		}
	}
}
Write-Output "reimport_stale: $($stale.Count) verouderde tiles"
if ($args -contains '--list') {
	$stale | ForEach-Object { Write-Output $_.Model }
	exit 0
}
if ($stale.Count -eq 0) { exit 0 }
foreach ($entry in $stale) {
	if (Test-Path $entry.Mesh) { Remove-Item $entry.Mesh -Force }
	$md5 = [System.IO.Path]::ChangeExtension($entry.Mesh, '.md5')
	if (Test-Path $md5) { Remove-Item $md5 -Force }
}
if (-not $env:GODOT_TIMEOUT) { $env:GODOT_TIMEOUT = 3600 }
Write-Output "[ stap 1/2 ] $($stale.Count) tiles importeren"
& "$root\tools\godot.ps1" --headless --import
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Output '[ stap 2/2 ] bibliotheken bijwerken'
& "$root\tools\godot.ps1" --headless --script tools/build/build_libraries.gd
exit $LASTEXITCODE
