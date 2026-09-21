# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "flutter_local_voice_agent")
project(${PROJECT_NAME} LANGUAGES CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "flutter_local_voice_agent_plugin")

set(NATIVE "${CMAKE_CURRENT_SOURCE_DIR}/../native")
set(FLVA_LIBS "${CMAKE_CURRENT_SOURCE_DIR}/libs")
set(SHERPA_DLL "${FLVA_LIBS}/sherpa-onnx-c-api.dll")
set(SHERPA_LIB "${FLVA_LIBS}/sherpa-onnx-c-api.lib")
set(ONNX_DLL "${FLVA_LIBS}/onnxruntime.dll")
set(ONNX_PROVIDERS_DLL "${FLVA_LIBS}/onnxruntime_providers_shared.dll")

# Official v1.12.14 win-x64-shared layout from tool/provision_runtime.py.
foreach(_required IN ITEMS
    "${SHERPA_DLL}"
    "${SHERPA_LIB}"
    "${ONNX_DLL}"
    "${ONNX_PROVIDERS_DLL}")
  if(NOT EXISTS "${_required}")
    message(FATAL_ERROR
      "Provision pinned sherpa-onnx v1.12.14 win-x64-shared libraries with "
      "tool/provision_runtime.py windows; missing ${_required}. "
      "No runtime download is performed.")
  endif()
endforeach()

add_library(sherpa SHARED IMPORTED)
set_target_properties(sherpa PROPERTIES
  IMPORTED_IMPLIB "${SHERPA_LIB}"
  IMPORTED_LOCATION "${SHERPA_DLL}")

# flva.cpp uses C++ exceptions. Keep them enabled here. The Flutter plugin
# target still uses apply_standard_settings (_HAS_EXCEPTIONS=0) and talks
# only through the C ABI.
add_library(flva_core STATIC "${NATIVE}/src/flva.cpp")
target_include_directories(flva_core PRIVATE
  "${NATIVE}/include"
  "${NATIVE}/src")
target_compile_features(flva_core PRIVATE cxx_std_17)
target_link_libraries(flva_core PUBLIC sherpa)
if(MSVC)
  target_compile_options(flva_core PRIVATE /EHsc)
  target_compile_definitions(flva_core PRIVATE _HAS_EXCEPTIONS=1)
endif()

# Optional local LLM stays CPU-only behind the existing compile gate.
# Do not enable CUDA, Vulkan, HIP or other GPU backends.
option(FLVA_ENABLE_LOCAL_LLM "Build optional local GGUF intelligence" OFF)
if(FLVA_ENABLE_LOCAL_LLM)
  set(FLVA_BUILD_LLM_SMOKE OFF CACHE BOOL "" FORCE)
  set(GGML_CUDA OFF CACHE BOOL "" FORCE)
  set(GGML_CUBLAS OFF CACHE BOOL "" FORCE)
  set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
  set(GGML_HIP OFF CACHE BOOL "" FORCE)
  set(GGML_HIPBLAS OFF CACHE BOOL "" FORCE)
  set(GGML_METAL OFF CACHE BOOL "" FORCE)
  set(GGML_BLAS OFF CACHE BOOL "" FORCE)
  set(GGML_OPENCL OFF CACHE BOOL "" FORCE)
  set(GGML_SYCL OFF CACHE BOOL "" FORCE)
  add_subdirectory("${NATIVE}/llm" "${CMAKE_CURRENT_BINARY_DIR}/llm")
  target_compile_definitions(flva_core PRIVATE FLVA_ENABLE_LLM=1)
  target_include_directories(flva_core PRIVATE "${NATIVE}/llm")
  target_link_libraries(flva_core PRIVATE flva_llm_adapter)
endif()

list(APPEND PLUGIN_SOURCES
  "flutter_local_voice_agent_plugin.cpp"
  "flutter_local_voice_agent_plugin.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/flutter_local_voice_agent/flutter_local_voice_agent_plugin_c_api.h"
  "flutter_local_voice_agent_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL NOMINMAX WIN32_LEAN_AND_MEAN)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${NATIVE}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  flva_core
  ole32
  uuid
  avrt)

# Bundle the provisioned official win-x64-shared DLLs next to the host.
set(flutter_local_voice_agent_bundled_libraries
  "${SHERPA_DLL}"
  "${ONNX_DLL}"
  "${ONNX_PROVIDERS_DLL}"
  PARENT_SCOPE
)
