cmake_minimum_required(VERSION 3.20)

# Top-level project for cde-plasma. Installs the *asset* components (Plasma
# theme, color scheme, SDDM theme, lock screen override, look-and-feel,
# activation script). The two compiled plugins live in their own subdirs
# (kwin_cde_decoration_kf6_plasma6/ and cde_qt_style_kf6_plasma6/ for
# Plasma 6; the _kf5_plasma5 siblings for Plasma 5) and are built separately
# by the packaging recipes — they each have their own project() and use
# different KDEInstallDirs flavors, so composing them via add_subdirectory()
# would conflict.
#
# Packaging flow (Arch/Debian/Fedora recipes all do this):
#   cmake -B build-decoration -S kwin_cde_decoration_kf6_plasma6
#   cmake --build build-decoration
#   DESTDIR=$pkg cmake --install build-decoration
#   cmake -B build-style -S cde_qt_style_kf6_plasma6
#   cmake --build build-style
#   DESTDIR=$pkg cmake --install build-style
#   cmake -B build-assets -S .
#   DESTDIR=$pkg cmake --install build-assets

project(cde-plasma VERSION 0.1.0 LANGUAGES NONE)

# GNUInstallDirs tries to infer an architecture-specific libdir when it is not
# set. This asset-only project enables no compiler language, so provide the
# unused libdir explicitly to keep package configure logs clean.
set(CMAKE_INSTALL_LIBDIR "lib" CACHE PATH "Object code libraries")
include(GNUInstallDirs)

set(KDE_DATADIR "${CMAKE_INSTALL_FULL_DATADIR}")
set(SDDM_THEMES_DIR "${KDE_DATADIR}/sddm/themes")
set(PLASMA_DIR      "${KDE_DATADIR}/plasma")
set(LOCKSCREEN_DIR  "${PLASMA_DIR}/shells/org.kde.plasma.desktop/contents/lockscreen")

# --- Plasma desktop themes (light + dark) ---
install(DIRECTORY commonality commonality-dark commonality-classic
    DESTINATION "${PLASMA_DIR}/desktoptheme"
    PATTERN ".git*" EXCLUDE
)

# --- Color schemes (light + dark) ---
install(FILES CDE.colors CDE-Dark.colors CDE-Chartreuse.colors CDE-ElectricPink.colors CDE-Classic.colors
    DESTINATION "${KDE_DATADIR}/color-schemes"
)

# --- SDDM login theme ---
install(DIRECTORY sddm-cde
    DESTINATION "${SDDM_THEMES_DIR}"
    PATTERN ".git*" EXCLUDE
)

# --- Look-and-feel packages (light + dark global themes) ---
install(DIRECTORY look-and-feel/org.kde.cde.desktop
                  look-and-feel/org.kde.cde-dark.desktop
    DESTINATION "${PLASMA_DIR}/look-and-feel"
    PATTERN ".git*" EXCLUDE
)

# --- Lock screen QML override ---
# Note: this overlays a file owned by Plasma's own package. Distro packages
# install it to a parallel path; the apply script copies it into place after
# backing up the original, so an uninstall can restore.
install(FILES lockscreen/LockScreenUi.qml
    DESTINATION "${KDE_DATADIR}/cde-plasma/lockscreen"
)

# --- Activation script ---
# Users run `cde-plasma-apply` once after install to switch KDE/SDDM to the
# CDE theme, install the lockscreen override (with backup), and configure
# the cursor. Mirrors what the source-tree install.sh does, but driven from
# the system-wide install.
install(PROGRAMS scripts/cde-plasma-apply
    DESTINATION "${CMAKE_INSTALL_FULL_BINDIR}"
)
install(PROGRAMS scripts/cde-plasma-unapply
    DESTINATION "${CMAKE_INSTALL_FULL_BINDIR}"
)
# cde-plasma-mode {light|dark} — one-shot convenience wrapper that flips all
# the coupled settings at once (the Global Theme GUI's per-category checkboxes
# sometimes skip Plasma Style / Colors / Window Decorations on 5.27 builds).
install(PROGRAMS scripts/cde-plasma-mode
    DESTINATION "${CMAKE_INSTALL_FULL_BINDIR}"
)
