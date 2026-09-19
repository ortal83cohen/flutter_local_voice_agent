#!/usr/bin/env python3
"""Compile/run native tests. Real-engine tests require explicit local assets."""
import argparse
from pathlib import Path
import subprocess


def run(command, timeout=120):
    print('$ ' + ' '.join(map(str, command)), flush=True)
    result = subprocess.run(command, timeout=timeout)
    print('exit=' + str(result.returncode), flush=True)
    if result.returncode:
        raise SystemExit(result.returncode)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', help='Local sherpa runtime lib directory')
    parser.add_argument('--assets', nargs=9, metavar='PATH', help='vad encoder decoder joiner asrTokens ttsModel ttsTokens ttsLexicon WAV')
    parser.add_argument('--sanitize', action='store_true')
    parser.add_argument('--ubsan', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    build = root / 'build/native'
    build.mkdir(parents=True, exist_ok=True)
    flags = ['-std=c++17', '-g', '-pthread', '-I'+str(root/'native/include'), '-I'+str(root/'native/src')]
    if args.sanitize: flags += ['-fsanitize=address,undefined']
    elif args.ubsan: flags += ['-fsanitize=undefined']
    ring = build / 'ring'
    run(['clang++', *flags, str(root/'native/tests/spsc_ring_test.cpp'), '-o', str(ring)])
    run([str(ring)], 20)
    print('PASS ring wrap/overflow/underflow/concurrency', flush=True)
    resampler = build / 'resampler'
    run(['clang++', *flags, str(root/'native/tests/resampler_test.cpp'), '-o',str(resampler)])
    run([str(resampler)],20)
    if args.runtime or args.assets:
        if not (args.runtime and args.assets): parser.error('--runtime and --assets must be supplied together')
        for name in ['real_engine_smoke', 'real_engine_failures']:
            exe=build/name
            run(['clang++', *flags, str(root/'native/src/flva.cpp'), str(root/f'native/tests/{name}.cpp'), '-L'+args.runtime, '-lsherpa-onnx-c-api', '-Wl,-rpath,'+args.runtime, '-o',str(exe)])
            run([str(exe), *args.assets], 180)
            print('PASS '+name, flush=True)
