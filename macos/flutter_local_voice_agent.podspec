Pod::Spec.new do |s|
  s.name = 'flutter_local_voice_agent'
  s.version = '0.1.0'
  s.summary = 'Native offline voice pipeline.'
  s.description = 'Locally provisioned speech models with explicit native lifecycle ownership.'
  s.homepage = 'https://pub.dev/packages/flutter_local_voice_agent'
  s.license = { :file => '../LICENSE' }
  s.author = 'flutter_local_voice_agent contributors'
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*.{h,mm}'
  s.public_header_files = 'Classes/FlutterLocalVoiceAgentPlugin.h'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '12.0'
  s.osx.deployment_target = '12.0'
  s.frameworks = 'AVFoundation', 'CoreAudio', 'AppKit'
  s.libraries = 'c++'
  # Stay a static CocoaPods target so FlutterMacOS symbols resolve in the host.
  # The example may load FlutterMacOS through Swift Package Manager.
  s.static_framework = true

  sherpa = File.join(__dir__, 'libs/libsherpa-onnx-c-api.dylib')
  onnx = File.join(__dir__, 'libs/libonnxruntime.1.17.1.dylib')
  unless File.exist?(sherpa) && File.exist?(onnx)
    raise 'Provision pinned sherpa-onnx v1.12.14 universal2 dylibs with tool/provision_runtime.py macos. The macos xcframework static bundle is not used.'
  end
  # Official osx-universal2-shared dylibs from macos/libs. Do not vendor the
  # macos xcframework static bundle. The unversioned onnxruntime symlink is
  # left in libs/ for runtime @rpath lookup; only the real files are linked.
  s.vendored_libraries = [
    'libs/libsherpa-onnx-c-api.dylib',
    'libs/libonnxruntime.1.17.1.dylib'
  ]

  # Optional local LLM stays CPU-only behind the existing gate. Do not enable
  # Metal, CUDA, BLAS or other GPU backends from this podspec.
  llm_enabled = ENV['FLVA_ENABLE_LOCAL_LLM'] == '1'
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/../native/include" "${PODS_TARGET_SRCROOT}/../native/src" "${PODS_TARGET_SRCROOT}/../native/llm"',
    'DEFINES_MODULE' => 'YES',
    'MACOSX_DEPLOYMENT_TARGET' => '12.0',
    'LIBRARY_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/libs"',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @loader_path @loader_path/Frameworks @executable_path/../Frameworks',
    'GCC_PREPROCESSOR_DEFINITIONS' => llm_enabled ? '$(inherited) FLVA_ENABLE_LLM=1' : '$(inherited)'
  }
end
