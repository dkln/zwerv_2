#!/usr/bin/env bash
# Analyseert audiobestanden (tempo, toonsoort, akkoorden, klankbalans, drums). Zie analyze.py.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$HERE/render.sh" --list > /dev/null  # zorgt dat de Python-omgeving bestaat
exec "$HERE/.venv/bin/python" -u "$HERE/analyze.py" "$@" < /dev/null
