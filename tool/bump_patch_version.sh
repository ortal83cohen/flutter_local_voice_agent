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
# Promote ## Unreleased notes into the new version. An empty or missing section
# keeps the automated placeholder. The Unreleased heading is removed either way.
awk -v version="$new" -v date_value="$date_value" '
function trim_blanks(text,    lines, i, n, start, end, out) {
  n = split(text, lines, "\n")
  start = 1
  end = n
  while (start <= end && lines[start] ~ /^[[:space:]]*$/) start++
  while (end >= start && lines[end] ~ /^[[:space:]]*$/) end--
  out = ""
  for (i = start; i <= end; i++) {
    out = out lines[i]
    if (i < end) out = out "\n"
  }
  return out
}
BEGIN { mode = "copy"; seen = 0 }
/^## Unreleased[[:space:]]*$/ {
  if (seen) { print "Error: duplicate Unreleased section" > "/dev/stderr"; exit 1 }
  seen = 1
  mode = "unreleased"
  next
}
mode == "unreleased" && /^## / { mode = "copy" }
mode == "unreleased" { unreleased = unreleased $0 "\n"; next }
{ kept = kept $0 "\n" }
END {
  notes = trim_blanks(unreleased)
  if (notes == "") notes = "- Automated patch release from main."
  sub(/^# Changelog\n/, "", kept)
  sub(/^\n+/, "", kept)
  printf "# Changelog\n\n## %s - %s\n\n%s\n\n%s", version, date_value, notes, kept
}
' "$changelog" > "$tmp_log"
mv "$tmp_pub" "$pubspec"; mv "$tmp_log" "$changelog"; echo "$new"
