#!/usr/bin/env python3
"""Self-test for build-time runtime provisioning. Uses tiny fixture archives."""
import hashlib
import io
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOL))
import provision_runtime as pr  # noqa: E402

EXPECTED = {
    'macos': (
        'libsherpa-onnx-c-api.dylib',
        'libonnxruntime.1.17.1.dylib',
        'libonnxruntime.dylib',
    ),
    'windows': (
        'sherpa-onnx-c-api.dll',
        'sherpa-onnx-c-api.lib',
        'onnxruntime.dll',
        'onnxruntime_providers_shared.dll',
    ),
    'linux': (
        'libsherpa-onnx-c-api.so',
        'libonnxruntime.so',
    ),
}

LIB_PREFIX = {
    'macos': 'sherpa-onnx-v1.12.14-osx-universal2-shared/lib',
    'windows': 'sherpa-onnx-v1.12.14-win-x64-shared/lib',
    'linux': 'sherpa-onnx-v1.12.14-linux-x64-shared/lib',
}


def _sha256(path):
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def _write_fixture(path, platform):
    """Write a tiny tar.bz2 that mirrors the official shared-library layout."""
    prefix = LIB_PREFIX[platform]
    with tarfile.open(path, 'w:bz2') as tar:
        directory = tarfile.TarInfo(prefix)
        directory.type = tarfile.DIRTYPE
        directory.mode = 0o755
        tar.addfile(directory)
        for name in EXPECTED[platform]:
            member = prefix + '/' + name
            if name == 'libonnxruntime.dylib':
                info = tarfile.TarInfo(member)
                info.type = tarfile.SYMTYPE
                info.linkname = 'libonnxruntime.1.17.1.dylib'
                tar.addfile(info)
                continue
            payload = (name + '\n').encode('ascii')
            info = tarfile.TarInfo(member)
            info.size = len(payload)
            info.mode = 0o644
            tar.addfile(info, io.BytesIO(payload))


def _dest(root, platform):
    return root / pr.DESKTOP_INSTALL[platform]['dest']


def _list_dest(dest):
    if not dest.exists():
        return ['<missing>']
    names = sorted(entry.name for entry in dest.iterdir())
    return names if names else ['<empty>']


class ProvisionRuntimeTest(unittest.TestCase):
    def setUp(self):
        self._assets = dict(pr.ASSETS)
        self._tmpdir = tempfile.TemporaryDirectory(prefix='flva-provision-test-')
        self.root = Path(self._tmpdir.name)
        for platform in EXPECTED:
            _dest(self.root, platform).mkdir(parents=True, exist_ok=True)

    def tearDown(self):
        pr.ASSETS = self._assets
        self._tmpdir.cleanup()

    def test_mismatch_copies_nothing_and_cli_exits_nonzero(self):
        for platform in EXPECTED:
            dest = _dest(self.root, platform)
            decoy = dest / 'keep-me.txt'
            decoy.write_text('untouched\n', encoding='ascii')
            archive = self.root / (platform + '-bad.tar.bz2')
            archive.write_bytes(b'not-a-sherpa-archive')
            with self.assertRaises(ValueError) as raised:
                pr.provision(platform, archive, self.root)
            self.assertIn('SHA-256 mismatch', str(raised.exception))
            listing = _list_dest(dest)
            print(platform + ' mismatch dest listing:', listing)
            self.assertEqual(listing, ['keep-me.txt'])
            sherpa_names = [name.name for name in dest.iterdir() if 'sherpa' in name.name.lower()]
            self.assertEqual(sherpa_names, [])

            result = subprocess.run(
                [
                    sys.executable,
                    str(TOOL / 'provision_runtime.py'),
                    platform,
                    '--archive',
                    str(archive),
                    '--root',
                    str(self.root),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            print(platform + ' mismatch CLI exit:', result.returncode)
            print(platform + ' mismatch CLI stderr:', result.stderr.strip())
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(_list_dest(dest), ['keep-me.txt'])

    def test_matching_digest_installs_expected_library_names(self):
        for platform in EXPECTED:
            archive = self.root / (platform + '-good.tar.bz2')
            _write_fixture(archive, platform)
            name, _official = self._assets[platform]
            pr.ASSETS[platform] = (name, _sha256(archive))
            pr.provision(platform, archive, self.root)
            dest = _dest(self.root, platform)
            listing = _list_dest(dest)
            print(platform + ' match dest listing:', listing)
            for expected in EXPECTED[platform]:
                self.assertIn(expected, listing)
            if platform == 'macos':
                link = dest / 'libonnxruntime.dylib'
                self.assertTrue(link.is_symlink())
                self.assertEqual(link.readlink().as_posix(), 'libonnxruntime.1.17.1.dylib')


def main():
    print('pubspec platforms and web key are checked by the parent work item.')
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(ProvisionRuntimeTest)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    raise SystemExit(main())
