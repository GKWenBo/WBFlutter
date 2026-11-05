cmake_minimum_required(VERSION 3.10)

project(nl_sign_kit LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Android Gradle Plugin 会把这里的产物打进 AAR/APK；
# Dart 侧用 DynamicLibrary.open('libnl_sign_kit.so') 加载。
add_library(nl_sign_kit SHARED nl_sign_kit.c)

target_include_directories(nl_sign_kit PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

set_target_properties(nl_sign_kit PROPERTIES
  OUTPUT_NAME nl_sign_kit
  PUBLIC_HEADER nl_sign_kit.h
)
