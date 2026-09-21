#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd); tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/valid"
echo 'name: fixture' > "$tmp/valid/pubspec.yaml"; echo 'version: 1.2.3' >> "$tmp/valid/pubspec.yaml"
echo '# Changelog' > "$tmp/valid/CHANGELOG.md"; echo '' >> "$tmp/valid/CHANGELOG.md"; echo '## 1.2.3 - unreleased' >> "$tmp/valid/CHANGELOG.md"
[ "$(RELEASE_DATE=2026-09-19 "$root/tool/bump_patch_version.sh" "$tmp/valid")" = 1.2.4 ]
grep -q '^version: 1.2.4$' "$tmp/valid/pubspec.yaml"; grep -q '^## 1.2.4 - 2026-09-19$' "$tmp/valid/CHANGELOG.md"
echo 'PASS bump patch positive case'

mkdir "$tmp/missing_pubspec"
if "$root/tool/bump_patch_version.sh" "$tmp/missing_pubspec" >/dev/null 2>&1; then exit 1; fi
echo 'PASS missing pubspec'

mkdir "$tmp/missing_changelog"
echo 'name: fixture' > "$tmp/missing_changelog/pubspec.yaml"; echo 'version: 1.2.3' >> "$tmp/missing_changelog/pubspec.yaml"
if "$root/tool/bump_patch_version.sh" "$tmp/missing_changelog" >/dev/null 2>&1; then exit 1; fi
echo 'PASS missing changelog'

mkdir "$tmp/bad_version"
echo 'name: fixture' > "$tmp/bad_version/pubspec.yaml"; echo 'version: not-a-version' >> "$tmp/bad_version/pubspec.yaml"
echo '# Changelog' > "$tmp/bad_version/CHANGELOG.md"
if "$root/tool/bump_patch_version.sh" "$tmp/bad_version" >/dev/null 2>&1; then exit 1; fi
echo 'PASS malformed package version'

mkdir "$tmp/bad_occupied"
echo 'name: fixture' > "$tmp/bad_occupied/pubspec.yaml"; echo 'version: 1.2.3' >> "$tmp/bad_occupied/pubspec.yaml"
echo '# Changelog' > "$tmp/bad_occupied/CHANGELOG.md"
if OCCUPIED_VERSIONS='1.2.x' "$root/tool/bump_patch_version.sh" "$tmp/bad_occupied" >/dev/null 2>&1; then exit 1; fi
echo 'PASS malformed occupied version'

mkdir "$tmp/duplicate"
echo 'name: fixture' > "$tmp/duplicate/pubspec.yaml"; echo 'version: 1.2.3' >> "$tmp/duplicate/pubspec.yaml"
echo '# Changelog' > "$tmp/duplicate/CHANGELOG.md"; echo '' >> "$tmp/duplicate/CHANGELOG.md"
echo '## 1.2.4 - already present' >> "$tmp/duplicate/CHANGELOG.md"
if "$root/tool/bump_patch_version.sh" "$tmp/duplicate" >/dev/null 2>&1; then exit 1; fi
echo 'PASS duplicate changelog version'

mkdir "$tmp/occupied"
echo 'name: fixture' > "$tmp/occupied/pubspec.yaml"; echo 'version: 1.2.3' >> "$tmp/occupied/pubspec.yaml"
echo '# Changelog' > "$tmp/occupied/CHANGELOG.md"; echo '' >> "$tmp/occupied/CHANGELOG.md"; echo '## 1.2.3 - unreleased' >> "$tmp/occupied/CHANGELOG.md"
[ "$(OCCUPIED_VERSIONS='1.2.4' RELEASE_DATE=2026-09-19 "$root/tool/bump_patch_version.sh" "$tmp/occupied")" = 1.2.5 ]
grep -q '^version: 1.2.5$' "$tmp/occupied/pubspec.yaml"; grep -q '^## 1.2.5 - 2026-09-19$' "$tmp/occupied/CHANGELOG.md"
echo 'PASS occupied candidate skipped'
