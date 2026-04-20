cmake_minimum_required(VERSION 3.20)

project(cde_qt_style_kf5 VERSION 0.1.0 LANGUAGES CXX)

find_package(ECM REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt5 REQUIRED COMPONENTS Core Gui Widgets)

get_target_property(QT_QMAKE_EXECUTABLE Qt5::qmake IMPORTED_LOCATION)
if(NOT QT_QMAKE_EXECUTABLE)
    find_program(QT_QMAKE_EXECUTABLE qmake REQUIRED)
endif()

execute_process(
    COMMAND "${QT_QMAKE_EXECUTABLE}" -query QT_INSTALL_PLUGINS
    OUTPUT_VARIABLE QT_PLUGIN_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

set(CDE_QT_STYLE_PLUGIN_DIR "${QT_PLUGIN_DIR}/styles" CACHE PATH "Qt styles plugin installation directory")

add_library(cde_qt_style_kf5 MODULE
    src/cdestyle.cpp
    src/cdestyle.h
    src/cde_qt_style.json
    src/plugin.cpp
)

set_target_properties(cde_qt_style_kf5 PROPERTIES
    PREFIX ""
)

target_link_libraries(cde_qt_style_kf5 PRIVATE
    Qt5::Core
    Qt5::Gui
    Qt5::Widgets
)

install(TARGETS cde_qt_style_kf5
    DESTINATION "${CDE_QT_STYLE_PLUGIN_DIR}"
)
