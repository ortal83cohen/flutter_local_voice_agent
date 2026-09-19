#!/usr/bin/env python3
"""Explicit BUILD-TIME download of pinned runtimes. Never called by the plugin."""
import argparse
import hashlib
from pathlib import Path
import shutil
import tarfile
import tempfile
import urllib.request

ASSETS = {
    'android': ('sherpa-onnx-v1.12.14-android.tar.bz2', 'f46e7179ae1e36477da7dfdc8cec35ecb6d558114871a4ec5210a9949f887497'),
    'ios': ('sherpa-onnx-v1.12.14-ios.tar.bz2', 'ce886f4d143f66e29606ee28604851247c3333fb0a94209ca248bc235751701f'),
}

def provision(platform, archive=None):
    root = Path(__file__).resolve().parent.parent
    name, digest = ASSETS[platform]
    with tempfile.TemporaryDirectory(prefix='flva-runtime-') as directory:
        scratch = Path(directory)
        source = Path(archive) if archive else scratch / name
        if not archive:
            url = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.12.14/' + name
            print('Explicit build-time download:', url)
            urllib.request.urlretrieve(url, source)
        h = hashlib.sha256()
        with source.open('rb') as f:
            for block in iter(lambda: f.read(1024 * 1024), b''): h.update(block)
        if h.hexdigest() != digest:
            raise ValueError('Runtime archive SHA-256 mismatch')
        with tarfile.open(source) as tar:
            tar.extractall(scratch, filter='data')
        if platform == 'android':
            target = root / 'android/src/main/jniLibs/arm64-v8a'
            target.mkdir(parents=True, exist_ok=True)
            for file in ('libsherpa-onnx-c-api.so', 'libonnxruntime.so'):
                shutil.copy2(scratch / 'jniLibs/arm64-v8a' / file, target / file)
        else:
            target = root / 'ios/Frameworks'
            target.mkdir(parents=True, exist_ok=True)
            for file in ('build-ios/sherpa-onnx.xcframework', 'build-ios/ios-onnxruntime/1.17.1/onnxruntime.xcframework'):
                p = scratch / file
                shutil.copytree(p, target / p.name, dirs_exist_ok=True, symlinks=True)
        print(platform + ': verified SHA-256 ' + digest)
        print('Provisioned build inputs. Distribution notice review remains required.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=ASSETS)
    parser.add_argument('--archive', help='Use a local archive without any network access')
    args = parser.parse_args()
    provision(args.platform, args.archive)
