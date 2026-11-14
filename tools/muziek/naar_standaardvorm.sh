#!/bin/sh
# Brings a composition in JSON to the standard form (docs/MUZIEK_JSON.md, "De standaardvorm"): the
# one structure every file in data/muziek/ has (tools/muziek/naar_standaardvorm.py).
# Usage: tools/muziek/naar_standaardvorm.sh <bestand.json>              (in place; the file as it was is
#                                                                        kept in origineel/ next to it)
#        tools/muziek/naar_standaardvorm.sh <bestand.json> <uit.json>   (written somewhere else)
#        tools/muziek/naar_standaardvorm.sh --controle <bestand.json>... (only: is it in the standard form?)
# Needs uv (https://docs.astral.sh/uv/).
CALLED_FROM="$(pwd)"
cd "$(dirname "$0")" || exit 1
if ! command -v uv > /dev/null 2>&1; then
	echo "naar_standaardvorm.sh: uv niet gevonden (installeren: https://docs.astral.sh/uv/)" >&2
	exit 127
fi
if [ "$#" -lt 1 ]; then
	echo "gebruik: tools/muziek/naar_standaardvorm.sh [--controle] <bestand.json> [<uit.json>]" >&2
	exit 2
fi
# the files as given from where the script was called: their full paths
for argument in "$@"; do
	shift
	case "$argument" in
		--*) ;;
		/*) ;;
		*) argument="$CALLED_FROM/$argument" ;;
	esac
	set -- "$@" "$argument"
done
exec uv run --quiet --with soundfile --with numpy python3 naar_standaardvorm.py "$@" < /dev/null
