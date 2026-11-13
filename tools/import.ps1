# Importeert alles wat nieuw of veranderd is (geluid, tiles, scripts met een class_name), zonder
# venster (Windows PowerShell; hetzelfde als tools/import.sh). Doe dit met de editor dicht: een
# import naast een open editor kan hem laten crashen.
#
#   tools\import.ps1
if (-not $env:GODOT_TIMEOUT) { $env:GODOT_TIMEOUT = 1800 }
& "$PSScriptRoot\godot.ps1" --headless --import
exit $LASTEXITCODE
