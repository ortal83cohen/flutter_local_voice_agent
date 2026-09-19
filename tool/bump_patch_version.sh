#!/bin/sh
set -eu
repo_root=${1:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
pubspec="$repo_root/pubspec.yaml"; changelog="$repo_root/CHANGELOG.md"
[ -f "$pubspec" ] || { echo "Error: pubspec.yaml not found" >&2; exit 1; }
[ -f "$changelog" ] || { echo "Error: CHANGELOG.md not found" >&2; exit 1; }
current=$(sed -n 's/^version: *//p' "$pubspec" | head -n1)
echo "$current" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "Error: invalid version: $current" >&2; exit 1; }
major=${current%%.*}; rest=${current#*.}; minor=${rest%%.*}; patch=${rest#*.}; new="$major.$minor.$((patch + 1))"
for occupied in ${OCCUPIED_VERSIONS-}; do echo "$occupied" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "Error: malformed occupied version: $occupied" >&2; exit 1; }; done
while :; do
  found=0; for occupied in ${OCCUPIED_VERSIONS-}; do [ "$occupied" = "$new" ] && found=1; done
  [ "$found" -eq 0 ] && break
  patch=$((patch + 1)); new="$major.$minor.$((patch + 1))"
done
grep -q '^# Changelog$' "$changelog" || { echo "Error: changelog must start with '# Changelog'" >&2; exit 1; }
grep -q "^## $new\([[:space:]]\|$\)" "$changelog" && { echo "Error: version already exists: $new" >&2; exit 1; }
date_value=${RELEASE_DATE:-$(date -u +%Y-%m-%d)}; tmp_pub=$(mktemp); tmp_log=$(mktemp); trap 'rm -f "$tmp_pub" "$tmp_log"' EXIT
sed "s/^version: .*/version: $new/" "$pubspec" > "$tmp_pub"
awk -v version="$new" -v date_value="$date_value" 'NR==1 {print; print ""; print "## " version " - " date_value; print ""; print "- Automated patch release from main."; next} {print}' "$changelog" > "$tmp_log"
mv "$tmp_pub" "$pubspec"; mv "$tmp_log" "$changelog"; echo "$new"
