#!/bin/sh
# Importeert alles wat nieuw of veranderd is (geluid, tiles, scripts met een class_name), zonder
# venster. Doe dit met de editor dicht: een import naast een open editor kan hem laten crashen.
# (Windows: tools\import.ps1.)
#
#   tools/import.sh
cd "$(dirname "$0")/.." || exit 1
GODOT_TIMEOUT="${GODOT_TIMEOUT:-1800}" exec tools/godot.sh --headless --import
