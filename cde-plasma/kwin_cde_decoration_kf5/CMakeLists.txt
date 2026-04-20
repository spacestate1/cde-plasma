cmake_minimum_required(VERSION 3.20)

project(kwin_cde_decoration VERSION 0.1.0 LANGUAGES CXX)

find_package(ECM REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Find Qt6/KF6 BEFORE including KDE macros so install paths resolve correctly
find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets)
find_package(KF6 REQUIRED COMPONENTS CoreAddons ConfigWidgets KCMUtils WidgetsAddons)
find_package(KDecoration3 REQUIRED)

include(KDEInstallDirs6)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

# --- Decoration plugin ---

add_library(kwin_cde_decoration MODULE
    src/cdebutton.cpp
    src/cdebutton.h
    src/cdedecoration.cpp
    src/cdedecoration.h
    src/plugin.cpp
)

set_target_properties(kwin_cde_decoration PROPERTIES
    OUTPUT_NAME "org.kde.cde.decoration"
    PREFIX ""
)

target_link_libraries(kwin_cde_decoration PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    KF6::CoreAddons
    KF6::ConfigCore
    KDecoration3::KDecoration
)

install(TARGETS kwin_cde_decoration
    DESTINATION ${KDE_INSTALL_PLUGINDIR}/${KDECORATION_PLUGIN_DIR}
)

# --- Configuration module (KCM) ---

add_library(kcm_cdedecoration MODULE
    src/cdedecorationkcm.cpp
    src/cdedecorationkcm.h
)

set_target_properties(kcm_cdedecoration PROPERTIES
    OUTPUT_NAME "kcm_cdedecoration"
    PREFIX ""
)

target_link_libraries(kcm_cdedecoration PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    KF6::CoreAddons
    KF6::ConfigCore
    KF6::ConfigWidgets
    KF6::KCMUtils
    KF6::WidgetsAddons
)

install(TARGETS kcm_cdedecoration
    DESTINATION ${KDE_INSTALL_PLUGINDIR}/${KDECORATION_PLUGIN_DIR}.kcm
)
