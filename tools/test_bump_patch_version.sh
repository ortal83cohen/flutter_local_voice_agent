#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd); tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/valid"
echo 'name: fixture' > "$tmp/valid/pubspec.yaml"; echo 'version: 1.2.3' >> "$tmp/valid/pubspec.yaml"
echo '# Changelog' > "$tmp/valid/CHANGELOG.md"; echo '' >> "$tmp/valid/CHANGELOG.md"; echo '## 1.2.3 - unreleased' >> "$tmp/valid/CHANGELOG.md"
[ "$(RELEASE_DATE=2026-09-19 "$root/tools/bump_patch_version.sh" "$tmp/valid")" = 1.2.4 ]
grep -q '^version: 1.2.4$' "$tmp/valid/pubspec.yaml"; grep -q '^## 1.2.4 - 2026-09-19$' "$tmp/valid/CHANGELOG.md"
echo 'PASS bump patch positive case'
