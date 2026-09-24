// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// Optional local LLM stays CPU-only behind the same gate as the CocoaPods podspec.
let llmEnabled = ProcessInfo.processInfo.environment["FLVA_ENABLE_LOCAL_LLM"] == "1"
let libsDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("../libs")
    .standardized
    .path

let nativeHeaders: [CXXSetting] = [
    .headerSearchPath("../../native/include"),
    .headerSearchPath("../../native/src"),
    .headerSearchPath("../../native/llm"),
]
let nativeHeaderSearch: [CSetting] = [
    .headerSearchPath("../../native/include"),
    .headerSearchPath("../../native/src"),
    .headerSearchPath("../../native/llm"),
]
var cxxSettings = nativeHeaders
if llmEnabled {
    cxxSettings.append(.define("FLVA_ENABLE_LLM", to: "1"))
}

let package = Package(
    name: "flutter_local_voice_agent",
    platforms: [
        .macOS("12.0"),
    ],
    products: [
        // Static, matching the podspec, so FlutterMacOS symbols resolve in the host.
        .library(
            name: "flutter-local-voice-agent",
            type: .static,
            targets: ["flutter_local_voice_agent"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_local_voice_agent",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "../Classes",
            publicHeadersPath: ".",
            cSettings: nativeHeaderSearch,
            cxxSettings: cxxSettings,
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AppKit"),
                .linkedLibrary("c++"),
                .linkedLibrary("sherpa-onnx-c-api"),
                .linkedLibrary("onnxruntime.1.17.1"),
                .unsafeFlags([
                    "-L", libsDirectory,
                    "-rpath", "@loader_path",
                    "-rpath", "@loader_path/Frameworks",
                    "-rpath", "@executable_path/../Frameworks",
                ]),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
