// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// Optional local LLM stays behind the same gate as the CocoaPods podspec.
let llmEnabled = ProcessInfo.processInfo.environment["FLVA_ENABLE_LOCAL_LLM"] == "1"

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

var binaryTargets: [Target] = [
    .binaryTarget(
        name: "sherpa-onnx",
        path: "../Frameworks/sherpa-onnx.xcframework"
    ),
    .binaryTarget(
        name: "onnxruntime",
        path: "../Frameworks/onnxruntime.xcframework"
    ),
]
var pluginDependencies: [Target.Dependency] = [
    .product(name: "FlutterFramework", package: "FlutterFramework"),
    .target(name: "sherpa-onnx"),
    .target(name: "onnxruntime"),
]
var cxxSettings = nativeHeaders
if llmEnabled {
    binaryTargets.append(
        .binaryTarget(
            name: "flva-llm",
            path: "../Frameworks/flva-llm.xcframework"
        )
    )
    pluginDependencies.append(.target(name: "flva-llm"))
    cxxSettings.append(.define("FLVA_ENABLE_LLM", to: "1"))
}

let package = Package(
    name: "flutter_local_voice_agent",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "flutter-local-voice-agent", targets: ["flutter_local_voice_agent"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_local_voice_agent",
            dependencies: pluginDependencies,
            path: "../Classes",
            publicHeadersPath: ".",
            cSettings: nativeHeaderSearch,
            cxxSettings: cxxSettings,
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("UIKit"),
                .linkedLibrary("c++"),
            ]
        ),
    ] + binaryTargets,
    cxxLanguageStandard: .cxx17
)
