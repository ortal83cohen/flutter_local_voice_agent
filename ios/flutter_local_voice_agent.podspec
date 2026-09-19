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
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.frameworks = 'AVFoundation'
  s.libraries = 'c++'
  frameworks = ['Frameworks/sherpa-onnx.xcframework', 'Frameworks/onnxruntime.xcframework']
  if ENV['FLVA_ENABLE_LOCAL_LLM'] == '1'
    frameworks += ['Frameworks/flva-llm.xcframework']
  end
  s.vendored_frameworks = frameworks
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/../native/include" "${PODS_TARGET_SRCROOT}/../native/src" "${PODS_TARGET_SRCROOT}/../native/llm"',
    'DEFINES_MODULE' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => ENV['FLVA_ENABLE_LOCAL_LLM'] == '1' ? '$(inherited) FLVA_ENABLE_LLM=1' : '$(inherited)'
  }
end
