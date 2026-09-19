#!/usr/bin/env python3
"""Hash a host-trusted LOCAL pack from an explicit provenance inventory."""
import argparse
import hashlib
import json
from pathlib import Path


def create(root, inventory):
    root = Path(root).resolve(strict=True)
    entries = json.loads(Path(inventory).read_text())
    if not isinstance(entries, list) or not 1 <= len(entries) <= 128:
        raise ValueError('Inventory must have 1..128 entries')
    files = []
    for entry in entries:
        relative = Path(entry['path'])
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError('Relative contained paths required')
        file = (root / relative).resolve(strict=True)
        if not file.is_relative_to(root) or not file.is_file():
            raise ValueError('File must remain inside model root')
        if not entry['source'] or not entry['license']:
            raise ValueError('Explicit source and license path required')
        h = hashlib.sha256()
        with file.open('rb') as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b''): h.update(block)
        files.append({**entry, 'bytes': file.stat().st_size, 'sha256': h.hexdigest()})
    document = {'schema': 1, 'profile': 'en-US-sherpa-vits', 'runtime': '1.12.14', 'inputRate': 16000, 'files': files}
    target = root / 'manifest.json'
    if target.exists():
        raise ValueError('Refusing to overwrite an existing manifest')
    target.write_text(json.dumps(document, indent=2) + '\n')
    print(target)
    print('Integrity manifest written. This does not grant model distribution rights.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory')
    parser.add_argument('--inventory', required=True)
    args = parser.parse_args()
    create(args.directory, args.inventory)
