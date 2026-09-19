#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd); tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
echo '{"versions":[{"version":"0.1.0"},{"version":"0.1.1"}]}' > "$tmp"
[ "$(python3 "$root/tool/occupied_pubdev_versions.py" "$tmp")" = '0.1.0 0.1.1' ]
echo '{"wrong":[]}' > "$tmp"
if python3 "$root/tool/occupied_pubdev_versions.py" "$tmp" >/dev/null 2>&1; then exit 1; fi
echo 'PASS occupied pub.dev versions positive and malformed-response negative cases'
