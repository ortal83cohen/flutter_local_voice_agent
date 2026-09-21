# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "flutter_local_voice_agent")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "flutter_local_voice_agent_plugin")

set(NATIVE "${CMAKE_CURRENT_SOURCE_DIR}/../native")
set(SHERPA_LIB "${CMAKE_CURRENT_SOURCE_DIR}/libs/libsherpa-onnx-c-api.so")
set(ONNX_LIB "${CMAKE_CURRENT_SOURCE_DIR}/libs/libonnxruntime.so")
if(NOT EXISTS "${SHERPA_LIB}" OR NOT EXISTS "${ONNX_LIB}")
  message(FATAL_ERROR
    "Provision pinned sherpa-onnx v1.12.14 linux-x64-shared libraries with tool/provision_runtime.py linux. Expected linux/libs/libsherpa-onnx-c-api.so and linux/libs/libonnxruntime.so. No runtime download is performed.")
endif()

add_library(sherpa_c_api SHARED IMPORTED GLOBAL)
set_target_properties(sherpa_c_api PROPERTIES IMPORTED_LOCATION "${SHERPA_LIB}")
add_library(onnxruntime SHARED IMPORTED GLOBAL)
set_target_properties(onnxruntime PROPERTIES IMPORTED_LOCATION "${ONNX_LIB}")

list(APPEND PLUGIN_SOURCES
  "flutter_local_voice_agent_plugin.cc"
  "${NATIVE}/src/flva.cpp"
)

add_library(${PLUGIN_NAME} SHARED
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_17)
# Shared worker sources are also built on Android without this runner's -Werror.
set_source_files_properties("${NATIVE}/src/flva.cpp" PROPERTIES COMPILE_OPTIONS "-Wno-error")

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  BUILD_WITH_INSTALL_RPATH TRUE
  INSTALL_RPATH "$ORIGIN")
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${NATIVE}/include"
  "${NATIVE}/src"
  "${NATIVE}/llm")

find_package(PkgConfig REQUIRED)
find_package(Threads REQUIRED)
# PulseAudio client API. PipeWire hosts that expose Pulse compatibility use the
# same client. ALSA-only is not an implementation path.
pkg_check_modules(PULSE REQUIRED IMPORTED_TARGET libpulse)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::PULSE)
target_link_libraries(${PLUGIN_NAME} PRIVATE sherpa_c_api onnxruntime)
target_link_libraries(${PLUGIN_NAME} PRIVATE Threads::Threads)

# Bundle imported runtimes plus any real SONAME files next to a symlink.
file(GLOB FLVA_LINUX_RUNTIME_LIBS
  "${CMAKE_CURRENT_SOURCE_DIR}/libs/libsherpa-onnx-c-api.so*"
  "${CMAKE_CURRENT_SOURCE_DIR}/libs/libonnxruntime.so*")
set(flutter_local_voice_agent_bundled_libraries
  ${FLVA_LINUX_RUNTIME_LIBS}
  PARENT_SCOPE
)

# Optional local LLM stays CPU-only behind the existing gate. Do not enable
# CUDA, Metal, BLAS, HIP or Vulkan from this desktop target.
option(FLVA_ENABLE_LOCAL_LLM "Build optional local GGUF intelligence" OFF)
if(FLVA_ENABLE_LOCAL_LLM)
  set(FLVA_BUILD_LLM_SMOKE OFF CACHE BOOL "" FORCE)
  set(GGML_CUDA OFF CACHE BOOL "" FORCE)
  set(GGML_METAL OFF CACHE BOOL "" FORCE)
  set(GGML_BLAS OFF CACHE BOOL "" FORCE)
  set(GGML_HIP OFF CACHE BOOL "" FORCE)
  set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
  add_subdirectory("${NATIVE}/llm" "${CMAKE_CURRENT_BINARY_DIR}/llm")
  target_compile_definitions(${PLUGIN_NAME} PRIVATE FLVA_ENABLE_LLM=1)
  target_link_libraries(${PLUGIN_NAME} PRIVATE flva_llm_adapter)
endif()
