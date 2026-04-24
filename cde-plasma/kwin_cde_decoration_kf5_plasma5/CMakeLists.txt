cmake_minimum_required(VERSION 3.20)

project(kwin_cde_decoration_kf5 VERSION 0.1.0 LANGUAGES CXX)

find_package(ECM REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt5 REQUIRED COMPONENTS Core Gui Widgets)
find_package(KF5 REQUIRED COMPONENTS CoreAddons Config ConfigWidgets KCMUtils WidgetsAddons)
find_package(KDecoration2 REQUIRED)

add_library(kwin_cde_decoration_kf5 MODULE
    src/cdebutton.cpp
    src/cdebutton.h
    src/cdedecoration.cpp
    src/cdedecoration.h
    src/cdedecorationkcm.cpp
    src/cdedecorationkcm.h
    src/cdecommon.h
    src/cdeconfig.h
    src/plugin.cpp
)

set_target_properties(kwin_cde_decoration_kf5 PROPERTIES
    OUTPUT_NAME "org.kde.cde.decoration"
    PREFIX ""
)

target_link_libraries(kwin_cde_decoration_kf5 PRIVATE
    Qt5::Core
    Qt5::Gui
    Qt5::Widgets
    KF5::CoreAddons
    KF5::ConfigCore
    KF5::ConfigWidgets
    KF5::KCMUtils
    KF5::WidgetsAddons
    KDecoration2::KDecoration
)

install(TARGETS kwin_cde_decoration_kf5
    DESTINATION ${KDE_INSTALL_PLUGINDIR}/org.kde.kdecoration2
)
