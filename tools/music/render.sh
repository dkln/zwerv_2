#!/usr/bin/env bash
# Rendert de muziek (tools/music/songs/) naar .ogg. Maakt bij de eerste keer een eigen
# Python-omgeving in tools/music/.venv met numpy en scipy.
# Alle argumenten gaan door naar render.py (zie: tools/music/render.sh --help).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$HERE/.venv"
if [ ! -x "$VENV/bin/python" ] || ! "$VENV/bin/python" -c "import numpy, scipy, soundfile" 2>/dev/null; then
  echo "Python-omgeving aanmaken in $VENV ..."
  [ -x "$VENV/bin/python" ] || python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --disable-pip-version-check numpy scipy soundfile < /dev/null
fi
exec "$VENV/bin/python" -u "$HERE/render.py" "$@" < /dev/null
