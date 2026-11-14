cmake_minimum_required(VERSION 3.16)
# Select the active Xcode compiler, not an unrelated Command Line Tools SDK.
# Only apply the known 27.2 SDK fallback when no SDK was explicitly selected.
if(CMAKE_HOST_APPLE)
    if(NOT DEFINED CMAKE_CXX_COMPILER AND "$ENV{CXX}" STREQUAL "")
        execute_process(COMMAND xcrun --find clang++ OUTPUT_VARIABLE _clang
            OUTPUT_STRIP_TRAILING_WHITESPACE RESULT_VARIABLE _clang_result)
        if(_clang_result EQUAL 0)
            set(CMAKE_CXX_COMPILER "${_clang}" CACHE FILEPATH "C++ compiler")
        endif()
    endif()
    if(NOT CMAKE_OSX_SYSROOT AND "$ENV{SDKROOT}" STREQUAL "")
        execute_process(COMMAND xcrun --show-sdk-path OUTPUT_VARIABLE _sdk
            OUTPUT_STRIP_TRAILING_WHITESPACE)
        if(EXISTS "${_sdk}")
            get_filename_component(_sdk_real "${_sdk}" REALPATH)
            if(_sdk_real MATCHES "MacOSX27\\.2\\.sdk$"
               AND EXISTS "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk")
                execute_process(COMMAND "${CMAKE_CXX_COMPILER}" --version
                    OUTPUT_VARIABLE _clang_version)
                if(_clang_version MATCHES "Apple clang version 21\\.")
                    set(_sdk "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk")
                endif()
            endif()
            set(CMAKE_OSX_SYSROOT "${_sdk}" CACHE PATH "macOS SDK" FORCE)
        endif()
    endif()
endif()

project(MuseScoreRichPresence VERSION 2.0.0 LANGUAGES CXX)

# Prefer the installed Qt SDK matching MuseScore's framework version.
if(APPLE AND NOT CMAKE_PREFIX_PATH AND NOT Qt6_DIR AND NOT Qt5_DIR)
    set(MUSESCORE_APP "/Applications/MuseScore 4.app" CACHE PATH "MuseScore app bundle")
    execute_process(COMMAND /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString"
        "${MUSESCORE_APP}/Contents/Frameworks/QtCore.framework/Resources/Info.plist"
        OUTPUT_VARIABLE _qt_version OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET RESULT_VARIABLE _qt_result)
    if(_qt_result EQUAL 0 AND _qt_version MATCHES "^[0-9]+\\.[0-9]+")
        string(REGEX MATCH "^[0-9]+\\.[0-9]+" _qt_minor "${_qt_version}")
        file(GLOB _qt_sdks LIST_DIRECTORIES true "$ENV{HOME}/Qt/${_qt_minor}*/macos")
        list(SORT _qt_sdks COMPARE NATURAL ORDER DESCENDING)
        foreach(_qt_sdk IN LISTS _qt_sdks)
            if(EXISTS "${_qt_sdk}/lib/cmake/Qt6/Qt6Config.cmake"
               OR EXISTS "${_qt_sdk}/lib/cmake/Qt5/Qt5Config.cmake")
                list(APPEND CMAKE_PREFIX_PATH "${_qt_sdk}")
                message(STATUS "Using MuseScore-compatible Qt SDK: ${_qt_sdk}")
                break()
            endif()
        endforeach()
    endif()
endif()

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${CMAKE_SOURCE_DIR}/dist" CACHE PATH "Plugin staging directory" FORCE)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core Network Qml)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core Network Qml)

add_library(DiscordIPC MODULE
    src/native/discordipc.cpp
    src/native/discordipc.h
    src/native/plugin.cpp
)
target_link_libraries(DiscordIPC PRIVATE
    Qt${QT_VERSION_MAJOR}::Core
    Qt${QT_VERSION_MAJOR}::Network
    Qt${QT_VERSION_MAJOR}::Qml
)

if(APPLE)
    set_target_properties(DiscordIPC PROPERTIES
        SUFFIX ".dylib"
        INSTALL_RPATH "@executable_path/../Frameworks"
    )
endif()

# Install a complete, relocatable MuseScore plugin directory.
install(TARGETS DiscordIPC
    LIBRARY DESTINATION MuseScoreRichPresence/DiscordIPC
    RUNTIME DESTINATION MuseScoreRichPresence/DiscordIPC
)
install(FILES src/plugin/DiscordIPC/qmldir
    DESTINATION MuseScoreRichPresence/DiscordIPC)
install(FILES src/plugin/RichPresence.qml
    DESTINATION MuseScoreRichPresence)

# A normal build produces the complete staged plugin automatically.
add_custom_target(stage_plugin ALL
    COMMAND "${CMAKE_COMMAND}" --install "${CMAKE_BINARY_DIR}" --config $<CONFIG>
    DEPENDS DiscordIPC
    VERBATIM
)
