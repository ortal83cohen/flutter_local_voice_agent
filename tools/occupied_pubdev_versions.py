#!/usr/bin/env python3
import json
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: occupied_pubdev_versions.py JSON")
with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
versions = data.get("versions")
if not isinstance(versions, list):
    raise SystemExit("Error: pub.dev response has no versions list")
print(" ".join(entry["version"] for entry in versions if isinstance(entry, dict) and isinstance(entry.get("version"), str)))
