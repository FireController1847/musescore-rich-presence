cmake_minimum_required(VERSION 3.16)
project(MuseScoreRichPresence VERSION 2.0.0 LANGUAGES CXX)

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
    set_target_properties(DiscordIPC PROPERTIES SUFFIX ".dylib")
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
