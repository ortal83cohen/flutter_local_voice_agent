#!/usr/bin/env python3
"""Build the optional CPU-only llama.cpp adapter as an iOS XCFramework."""

import argparse
import shutil
import subprocess
from pathlib import Path


def run(command: list[str]) -> None:
    print("+", " ".join(command), flush=True)
    subprocess.run(command, check=True)


def build_slice(
    *,
    cmake: str,
    ninja: str,
    adapter_source: Path,
    llama_source: Path,
    build_root: Path,
    sdk: str,
) -> Path:
    build_dir = build_root / sdk
    run([
        cmake,
        "-S", str(adapter_source),
        "-B", str(build_dir),
        "-G", "Ninja",
        f"-DCMAKE_MAKE_PROGRAM={ninja}",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_OSX_ARCHITECTURES=arm64",
        f"-DCMAKE_OSX_SYSROOT={sdk}",
        "-DCMAKE_SYSTEM_NAME=iOS",
        "-DCMAKE_OSX_DEPLOYMENT_TARGET=13.0",
        f"-DLLAMA_CPP_SOURCE_DIR={llama_source}",
        "-DFLVA_ENABLE_LOCAL_LLM=ON",
        "-DFLVA_BUILD_LLM_SMOKE=OFF",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DGGML_METAL=OFF",
        "-DGGML_ACCELERATE=OFF",
        "-DGGML_BLAS=OFF",
        "-DGGML_OPENMP=OFF",
        "-DGGML_CPU_ALL_VARIANTS=OFF",
        "-DGGML_BACKEND_DL=OFF",
    ])
    run([cmake, "--build", str(build_dir), "--parallel", "2"])
    archives = sorted(build_dir.rglob("*.a"))
    if not archives or not any(path.name == "libflva_llm_adapter.a" for path in archives):
        raise RuntimeError(f"expected adapter archive was not built for {sdk}")
    merged = build_root / "archives" / sdk / "libflva_llm.a"
    merged.parent.mkdir(parents=True, exist_ok=True)
    run(["libtool", "-static", "-o", str(merged), *map(str, archives)])
    return merged


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path,
                        help="Pinned llama.cpp source checkout")
    parser.add_argument("--cmake", required=True,
                        help="CMake executable to use")
    parser.add_argument("--output", type=Path,
                        default=Path(__file__).resolve().parent.parent / "build" / "llm-ios",
                        help="Directory for build products and XCFramework")
    args = parser.parse_args()

    llama_source = args.source.resolve()
    adapter_source = Path(__file__).resolve().parent.parent / "native" / "llm"
    output = args.output.resolve()
    if not (llama_source / "include" / "llama.h").is_file():
        raise RuntimeError("--source does not contain include/llama.h")
    if not Path(args.cmake).is_file():
        raise RuntimeError("--cmake is not an executable file")
    if not (llama_source / "LICENSE").is_file():
        raise RuntimeError("pinned llama.cpp source has no LICENSE notice")

    output.mkdir(parents=True, exist_ok=True)
    bundled_ninja = Path(args.cmake).resolve().parent / "ninja"
    ninja = str(bundled_ninja if bundled_ninja.is_file() else shutil.which("ninja") or "")
    if not ninja:
        raise RuntimeError("Ninja was not found next to --cmake or on PATH")
    headers = output / "headers"
    headers.mkdir(exist_ok=True)
    shutil.copy2(adapter_source / "llm_adapter.h", headers / "llm_adapter.h")
    shutil.copy2(llama_source / "LICENSE", headers / "NOTICE-llama.cpp.txt")

    device = build_slice(
        cmake=args.cmake,
        ninja=ninja,
        adapter_source=adapter_source,
        llama_source=llama_source,
        build_root=output,
        sdk="iphoneos",
    )
    simulator = build_slice(
        cmake=args.cmake,
        ninja=ninja,
        adapter_source=adapter_source,
        llama_source=llama_source,
        build_root=output,
        sdk="iphonesimulator",
    )
    framework = output / "flva-llm.xcframework"
    if framework.exists():
        shutil.rmtree(framework)
    run([
        "xcodebuild", "-create-xcframework",
        "-library", str(device), "-headers", str(headers),
        "-library", str(simulator), "-headers", str(headers),
        "-output", str(framework),
    ])
    print(f"XCFramework: {framework}")


if __name__ == "__main__":
    main()
