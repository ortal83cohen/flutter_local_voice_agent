#!/usr/bin/env python3
"""Explicit BUILD-TIME download of pinned runtimes. Never called by the plugin."""
import argparse
import hashlib
from pathlib import Path
import shutil
import tarfile
import tempfile
import urllib.request

# Digests for windows and linux were measured from the downloaded official
# v1.12.14 bytes (python hashlib + shasum -a 256). They were not copied from a UI.
ASSETS = {
    'android': ('sherpa-onnx-v1.12.14-android.tar.bz2', 'f46e7179ae1e36477da7dfdc8cec35ecb6d558114871a4ec5210a9949f887497'),
    'ios': ('sherpa-onnx-v1.12.14-ios.tar.bz2', 'ce886f4d143f66e29606ee28604851247c3333fb0a94209ca248bc235751701f'),
    'macos': ('sherpa-onnx-v1.12.14-osx-universal2-shared.tar.bz2', '7e0f7bec6b7a428e7594385f62ebb5c3fc9fadc863a12005302bfd67a45ee413'),
    'windows': ('sherpa-onnx-v1.12.14-win-x64-shared.tar.bz2', '78fa331bac4d20828a867b14283950727ce668fe751d1a792352b7e035b0ffe1'),
    'linux': ('sherpa-onnx-v1.12.14-linux-x64-shared.tar.bz2', 'b898ed5d7b989192ac6c60b6c0076f9de2e89766930bf1e11738aacbf45f5ed8'),
}

# Official archive lib/ layouts inspected from the v1.12.14 shared tarballs.
# macOS xcframework static bundle is intentionally not used.
DESKTOP_INSTALL = {
    'macos': {
        'dest': Path('macos/libs'),
        'lib_dir': Path('sherpa-onnx-v1.12.14-osx-universal2-shared/lib'),
        'files': (
            'libsherpa-onnx-c-api.dylib',
            'libonnxruntime.1.17.1.dylib',
            'libonnxruntime.dylib',
        ),
    },
    'windows': {
        'dest': Path('windows/libs'),
        'lib_dir': Path('sherpa-onnx-v1.12.14-win-x64-shared/lib'),
        'files': (
            'sherpa-onnx-c-api.dll',
            'sherpa-onnx-c-api.lib',
            'onnxruntime.dll',
            'onnxruntime_providers_shared.dll',
        ),
    },
    'linux': {
        'dest': Path('linux/libs'),
        'lib_dir': Path('sherpa-onnx-v1.12.14-linux-x64-shared/lib'),
        'files': (
            'libsherpa-onnx-c-api.so',
            'libonnxruntime.so',
        ),
    },
}

RELEASE_URL = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.12.14/'


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def _copy_library(source, destination_dir):
    target = destination_dir / source.name
    if source.is_symlink():
        if target.exists() or target.is_symlink():
            target.unlink()
        target.symlink_to(source.readlink())
        return
    if not source.exists():
        raise FileNotFoundError('Expected library missing from archive: ' + source.name)
    shutil.copy2(source, target)


def _install_android(scratch, root):
    target = root / 'android/src/main/jniLibs/arm64-v8a'
    target.mkdir(parents=True, exist_ok=True)
    for file in ('libsherpa-onnx-c-api.so', 'libonnxruntime.so'):
        shutil.copy2(scratch / 'jniLibs/arm64-v8a' / file, target / file)


def _install_ios(scratch, root):
    target = root / 'ios/Frameworks'
    target.mkdir(parents=True, exist_ok=True)
    for file in ('build-ios/sherpa-onnx.xcframework', 'build-ios/ios-onnxruntime/1.17.1/onnxruntime.xcframework'):
        path = scratch / file
        shutil.copytree(path, target / path.name, dirs_exist_ok=True, symlinks=True)


def _install_desktop(platform, scratch, root):
    spec = DESKTOP_INSTALL[platform]
    target = root / spec['dest']
    lib_dir = scratch / spec['lib_dir']
    target.mkdir(parents=True, exist_ok=True)
    for file in spec['files']:
        _copy_library(lib_dir / file, target)


def provision(platform, archive=None, root=None):
    root = Path(root) if root is not None else Path(__file__).resolve().parent.parent
    name, digest = ASSETS[platform]
    with tempfile.TemporaryDirectory(prefix='flva-runtime-') as directory:
        scratch = Path(directory)
        source = Path(archive) if archive else scratch / name
        if not archive:
            url = RELEASE_URL + name
            print('Explicit build-time download:', url)
            urllib.request.urlretrieve(url, source)
        if sha256_file(source) != digest:
            raise ValueError('Runtime archive SHA-256 mismatch')
        with tarfile.open(source) as tar:
            tar.extractall(scratch, filter='data')
        if platform == 'android':
            _install_android(scratch, root)
        elif platform == 'ios':
            _install_ios(scratch, root)
        else:
            _install_desktop(platform, scratch, root)
        print(platform + ': verified SHA-256 ' + digest)
        print('Provisioned build inputs. Distribution notice review remains required.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=ASSETS)
    parser.add_argument('--archive', help='Use a local archive without any network access')
    parser.add_argument('--root', help='Plugin package root. Defaults to the repository root')
    args = parser.parse_args()
    provision(args.platform, args.archive, args.root)
