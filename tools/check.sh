#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd); cd "$root"
for binary in flutter dart python3; do command -v "$binary" >/dev/null 2>&1 || { echo "Preflight failed: missing $binary" >&2; exit 1; }; done
python3 tools/lint_wiki.py; echo 'Stage 1 passed: wiki lint'
flutter pub get; (cd example && flutter pub get); echo 'Stage 2 passed: dependencies'
format_paths='lib example/lib'
[ -d test ] && format_paths="$format_paths test"
[ -d example/test ] && format_paths="$format_paths example/test"
dart format --output=none --set-exit-if-changed $format_paths; echo 'Stage 3 passed: format'
dart analyze --fatal-infos --fatal-warnings; (cd example && dart analyze --fatal-infos --fatal-warnings); echo 'Stage 4 passed: analysis'
if [ -d test ]; then flutter test; else echo 'No root test directory; skipping package tests'; fi
if [ -d example/test ]; then (cd example && flutter test); else echo 'No example/test directory; skipping example tests'; fi
python3 tools/test_native.py; echo 'Stage 5 passed: tests'
dart pub publish --dry-run; echo 'Stage 6 passed: package dry run'
sh tools/test_bump_patch_version.sh; sh tools/test_occupied_pubdev_versions.sh; echo 'Stage 7 passed: release helper tests'
