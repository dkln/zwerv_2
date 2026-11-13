# Bakt de samengevoegde meshes van de kaarten vooraf in de cache (user://merged), zodat het
# spel bij het starten alleen hoeft te laden (Windows PowerShell; hetzelfde als tools/bake.sh).
# Draai dit na het bouwen van de stad, na het opnieuw opbouwen van de tiles, of na een
# wijziging aan layer_baker.gd. Zonder venster (headless).
#
#   tools\bake.ps1                       alle kaarten met een DetailNiveau (scenes/*.tscn)
#   tools\bake.ps1 opnieuw               eerst de cache van die kaarten leeg: alles opnieuw
#   tools\bake.ps1 scenes/stad.tscn      alleen deze kaart
if (-not $env:GODOT_TIMEOUT) { $env:GODOT_TIMEOUT = 3600 }
& "$PSScriptRoot\godot.ps1" --headless --script tools/build/bake_maps.gd '--' @args
exit $LASTEXITCODE
