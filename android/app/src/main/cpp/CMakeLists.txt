cmake_minimum_required(VERSION 3.22)
project(ytteria)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Release optimizations
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")

# ARM NEON (always available on Android ARM64)
if(ANDROID_ABI STREQUAL "arm64-v8a")
  add_compile_options(-march=armv8-a+fp16)
endif()

add_library(
    ytteria
    SHARED
    ytteria/ytteria.cpp
)

target_include_directories(ytteria PRIVATE ytteria)

target_compile_options(ytteria PRIVATE -O3)

target_link_libraries(ytteria
    android
    log
)

# Strip in release
set_target_properties(ytteria PROPERTIES
    LINK_FLAGS_RELEASE "-s"
)
