#!/bin/bash
#
# CDE Plasma Theme Installer
# Installs: KWin decoration, Qt widget style, Plasma theme, SDDM theme, lock screen, color scheme, cursor
# Supports both Plasma 5 (KF5/Qt5) and Plasma 6 (KF6/Qt6)
#

set -e

AUTO_YES=false
while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) AUTO_YES=true; shift ;;
        *) shift ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install-$(date '+%Y%m%d-%H%M%S').log"

# Send all output to both terminal and timestamped log file.
exec > >(while IFS= read -r line; do
    printf '%s\n' "$line"
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line" >> "$LOG_FILE"
done) 2>&1

echo "=== CDE Plasma Theme Installer ==="
echo "Log file: $LOG_FILE"
echo

# Detect Plasma version (5 or 6)
PLASMA_VERSION=6
detect_plasma_version() {
    # Default to 6 for newer systems
    PLASMA_VERSION=6

    # Method 1: Check plasma-desktop package version (Debian/Ubuntu)
    if command -v dpkg &>/dev/null; then
        local plasma_pkg_ver
        plasma_pkg_ver=$(dpkg -l plasma-desktop 2>/dev/null | awk "/^ii/{print $3}" | grep -oP "^\d+:\K\d+" | head -1)
        if [ "$plasma_pkg_ver" = "5" ]; then
            PLASMA_VERSION=5
            return
        fi
    fi

    # Method 2: Check for KDecoration2 vs KDecoration3 headers
    if [ -d /usr/include/KDecoration2 ]; then
        PLASMA_VERSION=5
        return
    fi

    if [ -d /usr/include/KF6/KDecoration3 ] || [ -d /usr/include/kdecoration3 ]; then
        PLASMA_VERSION=6
        return
    fi

    # Method 3: Check plasmashell version
    if command -v plasmashell &>/dev/null; then
        local plasma_ver
        plasma_ver=$(plasmashell --version 2>/dev/null | grep -oP "\d+" | head -1 || echo "6")
        if [ "$plasma_ver" = "5" ]; then
            PLASMA_VERSION=5
        fi
    fi
}

detect_plasma_version
echo "Detected Plasma version: $PLASMA_VERSION"
echo

# Returns true if systemd is the running init system
has_systemd() {
    [ -d /run/systemd/system ]
}

# Detect distro family
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            arch|manjaro|endeavouros|garuda|cachyos)
                echo "arch"
                ;;
            ubuntu|debian|linuxmint|pop|elementary|zorin)
                echo "debian"
                ;;
            fedora|rhel|centos|rocky|alma|nobara)
                echo "fedora"
                ;;
            *)
                case "$ID_LIKE" in
                    *arch*)  echo "arch" ;;
                    *debian*|*ubuntu*) echo "debian" ;;
                    *fedora*|*rhel*)   echo "fedora" ;;
                    *)       echo "unknown" ;;
                esac
                ;;
        esac
    else
        echo "unknown"
    fi
}

# Install build dependencies for Plasma 5 (KF5/Qt5)
install_deps_plasma5() {
    local distro
    distro="$(detect_distro)"

    echo "Installing Plasma 5 (KF5/Qt5) dependencies..."

    case "$distro" in
        arch)
            echo "Installing dependencies via pacman..."
            sudo pacman -S --needed --noconfirm \
                cmake make gcc pkg-config \
                qt5-base extra-cmake-modules \
                kconfig kcoreaddons kdecoration \
                curl
            ;;
        debian)
            echo "Installing dependencies via apt..."
            sudo apt-get update -qq
            sudo apt-get install -y \
                cmake make g++ pkg-config \
                qtbase5-dev qtbase5-dev-tools \
                extra-cmake-modules \
                libkf5coreaddons-dev libkf5config-dev \
                libkdecorations2-dev \
                curl
            ;;
        fedora)
            echo "Installing dependencies via dnf/yum..."
            local pm="dnf"
            command -v dnf &>/dev/null || pm="yum"
            sudo "$pm" install -y \
                cmake make gcc-c++ pkg-config \
                qt5-qtbase-devel \
                extra-cmake-modules \
                kf5-kcoreaddons-devel kf5-kconfig-devel \
                kdecoration-devel \
                curl
            ;;
        *)
            echo "Unknown distro. Please install manually:"
            echo "  cmake, g++, pkg-config, Qt5, extra-cmake-modules,"
            echo "  KF5 CoreAddons, Config, KDecoration2"
            exit 1
            ;;
    esac
}

# Install build dependencies for Plasma 6 (KF6/Qt6)
install_deps_plasma6() {
    local distro
    distro="$(detect_distro)"

    echo "Installing Plasma 6 (KF6/Qt6) dependencies..."

    case "$distro" in
        arch)
            echo "Installing dependencies via pacman..."
            sudo pacman -S --needed --noconfirm \
                cmake make gcc pkg-config \
                qt6-base extra-cmake-modules \
                kcoreaddons kconfig kdecoration \
                kcolorscheme kconfigwidgets kcmutils kwidgetsaddons \
                curl
            ;;
        debian)
            echo "Installing dependencies via apt..."
            sudo apt-get update -qq
            sudo apt-get install -y \
                cmake make g++ pkg-config \
                qt6-base-dev qt6-base-private-dev \
                extra-cmake-modules \
                libkf6coreaddons-dev libkf6config-dev libkf6configwidgets-dev \
                libkf6kcmutils-dev libkf6widgetsaddons-dev \
                libkdecorations3-dev \
                curl
            ;;
        fedora)
            echo "Installing dependencies via dnf/yum..."
            local pm="dnf"
            command -v dnf &>/dev/null || pm="yum"
            sudo "$pm" install -y \
                cmake make gcc-c++ pkg-config \
                qt6-qtbase-devel \
                extra-cmake-modules \
                kf6-kcoreaddons-devel kf6-kconfig-devel kf6-kconfigwidgets-devel \
                kf6-kcmutils-devel kf6-kwidgetsaddons-devel \
                kdecoration-devel \
                curl
            ;;
        *)
            echo "Unknown distro. Please install manually:"
            echo "  cmake, g++, pkg-config, Qt6, extra-cmake-modules,"
            echo "  KF6 CoreAddons, Config, ConfigWidgets, KCMUtils, WidgetsAddons, KDecoration3"
            exit 1
            ;;
    esac
}

# Install dependencies based on detected Plasma version
install_deps() {
    local distro
    distro="$(detect_distro)"
    echo "Detected distro family: $distro"

    if [ "$PLASMA_VERSION" = "5" ]; then
        install_deps_plasma5
    else
        install_deps_plasma6
    fi
}

# Check for required build dependencies
check_deps() {
    local need_install=false

    for cmd in cmake make g++ pkg-config; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Missing: $cmd"
            need_install=true
        fi
    done

    if [ "$PLASMA_VERSION" = "5" ]; then
        if ! pkg-config --exists Qt5Core 2>/dev/null; then
            echo "Missing: Qt5 development packages"
            need_install=true
        fi
    else
        if ! pkg-config --exists Qt6Core 2>/dev/null; then
            echo "Missing: Qt6 development packages"
            need_install=true
        fi
    fi

    if [ "$need_install" = true ]; then
        echo
        echo "Installing missing dependencies..."
        install_deps
        echo

        for cmd in cmake make g++ pkg-config; do
            if ! command -v "$cmd" &>/dev/null; then
                echo "ERROR: $cmd still missing after install attempt."
                exit 1
            fi
        done

        if [ "$PLASMA_VERSION" = "5" ]; then
            if ! pkg-config --exists Qt5Core 2>/dev/null; then
                echo "ERROR: Qt5 still missing after install attempt."
                exit 1
            fi
        else
            if ! pkg-config --exists Qt6Core 2>/dev/null; then
                echo "ERROR: Qt6 still missing after install attempt."
                exit 1
            fi
        fi
        echo "All dependencies installed."
    else
        echo "All dependencies present."
    fi
    echo
}

# Build and install KWin decoration
install_kwin_decoration() {
    echo "[1/8] Building KWin decoration..."

    local src_dir
    if [ "$PLASMA_VERSION" = "5" ]; then
        src_dir="$SCRIPT_DIR/kwin_cde_decoration_kf5_plasma5"
        echo "  Using Plasma 5 (KF5/KDecoration2) source..."
    else
        src_dir="$SCRIPT_DIR/kwin_cde_decoration_kf5"
        echo "  Using Plasma 6 (KF6/KDecoration3) source..."
    fi

    cd "$src_dir"
    rm -rf build && mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release
    make -j"$(nproc)"
    echo "Installing KWin decoration (requires sudo)..."
    sudo make install

    # Clean up old misnamed plugins
    if [ "$PLASMA_VERSION" = "6" ]; then
        local plugin_dir
        plugin_dir="$(pkg-config --variable=plugindir Qt6Core 2>/dev/null || echo /usr/lib/qt6/plugins)"
        for old in "$plugin_dir/org.kde.kdecoration3/kwin_cde_decoration.so" \
                   "$plugin_dir/org.kde.kdecoration3/libkwin_cde_decoration.so"; do
            if [ -f "$old" ]; then
                echo "  Removing old misnamed plugin: $old"
                sudo rm -f "$old"
            fi
        done
    fi

    echo "KWin decoration installed."
    echo
}

# Build and install Qt widget style
install_qt_style() {
    echo "[2/8] Building Qt widget style..."

    local src_dir
    if [ "$PLASMA_VERSION" = "5" ]; then
        src_dir="$SCRIPT_DIR/cde_qt_style_kf5_plasma5"
        echo "  Using Qt5 style source..."
    else
        src_dir="$SCRIPT_DIR/cde_qt_style_kf5"
        echo "  Using Qt6 style source..."
    fi

    cd "$src_dir"
    rm -rf build && mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release
    make -j"$(nproc)"
    echo "Installing Qt style (requires sudo)..."
    sudo make install
    echo "Qt widget style installed."
    echo
}

# Install Plasma desktop theme
install_plasma_theme() {
    echo "[3/8] Installing Plasma theme..."
    local theme_dir="$HOME/.local/share/plasma/desktoptheme/commonality"
    mkdir -p "$theme_dir"
    cp -r "$SCRIPT_DIR/commonality/"* "$theme_dir/"
    echo "Plasma theme installed to $theme_dir"
    echo
}

# Install color scheme
install_color_scheme() {
    echo "[4/8] Installing color scheme..."
    local colors_dir="$HOME/.local/share/color-schemes"
    mkdir -p "$colors_dir"
    cp "$SCRIPT_DIR/CDE.colors" "$colors_dir/"
    echo "Color scheme installed to $colors_dir"
    echo
}

# Resolve which cursor theme to use
resolve_cursor_theme() {
    for theme in Hackneyed LHackneyed Vanilla-DMZ DMZ-Black Adwaita breeze_cursors; do
        if [ -d "/usr/share/icons/$theme/cursors" ]; then
            echo "$theme"
            return
        fi
    done
    echo "default"
}

# Install cursor theme
install_cursor() {
    echo "[5/8] Installing cursor theme..."
    local cursor_theme
    cursor_theme="$(resolve_cursor_theme)"

    if [ "$cursor_theme" != "default" ]; then
        sudo mkdir -p /usr/share/icons/default
        sudo tee /usr/share/icons/default/index.theme > /dev/null << EOF
[Icon Theme]
Inherits=$cursor_theme
EOF
        echo "System default cursor set to $cursor_theme"
    fi
    echo "Cursor theme configured."
    echo
}

# Install SDDM login theme
install_sddm_theme() {
    echo "[6/8] Installing SDDM login theme..."
    sudo cp -r "$SCRIPT_DIR/sddm-cde" /usr/share/sddm/themes/

    local distro
    distro="$(detect_distro)"
    if [ "$distro" = "debian" ] || [ "$distro" = "arch" ] || [ "$distro" = "fedora" ]; then
        local meta="/usr/share/sddm/themes/sddm-cde/metadata.desktop"
        if [ "$PLASMA_VERSION" = "6" ] && ! sudo grep -q "^QtVersion=6" "$meta" 2>/dev/null; then
            sudo bash -c "printf 'Theme-API=2.0\nQtVersion=6\n' >> '$meta'"
            echo "  Patched metadata.desktop with Qt6 flags"
        fi
    fi

    sudo mkdir -p /etc/sddm.conf.d
    local sddm_cursor
    sddm_cursor="$(resolve_cursor_theme)"
    sudo tee /etc/sddm.conf.d/sddm-cde-theme.conf > /dev/null << EOF
[Theme]
Current=sddm-cde
CursorTheme=$sddm_cursor
EOF

    if has_systemd; then
        sudo mkdir -p /etc/systemd/system/sddm.service.d
        sudo tee /etc/systemd/system/sddm.service.d/cde-theme.conf > /dev/null << EOF
[Service]
ExecStartPre=/bin/sh -c '[ -f /etc/sddm.conf.d/sddm-cde-theme.conf ] || echo -e "[Theme]\nCurrent=sddm-cde\nCursorTheme=$sddm_cursor" > /etc/sddm.conf.d/sddm-cde-theme.conf'
EOF
        sudo systemctl daemon-reload
    fi

    echo "SDDM theme installed."
    echo
}

# Install look-and-feel theme
install_look_and_feel() {
    echo "[7/8] Installing look-and-feel theme..."
    local laf_dir="$HOME/.local/share/plasma/look-and-feel"
    mkdir -p "$laf_dir"
    cp -r "$SCRIPT_DIR/look-and-feel/org.kde.cde.desktop" "$laf_dir/"
    echo "Look-and-feel theme installed."
    echo
}

# Install CDE lock screen
install_lockscreen() {
    echo "[8/8] Installing CDE lock screen..."
    local lockscreen_dir="/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen"

    if [ ! -d "$lockscreen_dir" ]; then
        echo "  Lock screen directory not found, skipping."
        echo
        return
    fi

    local backup_dir="${lockscreen_dir}.breeze-backup"
    if [ ! -d "$backup_dir" ]; then
        echo "  Backing up original lock screen..."
        sudo cp -r "$lockscreen_dir" "$backup_dir"
    fi

    if [ -f "$SCRIPT_DIR/lockscreen/LockScreenUi.qml" ]; then
        sudo cp "$SCRIPT_DIR/lockscreen/LockScreenUi.qml" "$lockscreen_dir/LockScreenUi.qml"
        echo "CDE lock screen installed."
    else
        echo "  Lock screen source not found, skipping."
    fi
    echo
}

# Configure KDE to use the theme
configure_kde() {
    echo "Configuring KDE settings..."

    local kwriteconfig_cmd="kwriteconfig5"
    if [ "$PLASMA_VERSION" = "6" ]; then
        kwriteconfig_cmd="kwriteconfig6"
    fi

    $kwriteconfig_cmd --file kdeglobals --group KDE --key widgetStyle "cde"
    $kwriteconfig_cmd --file kwinrc --group org.kde.kdecoration2 --key library "org.kde.cde.decoration"
    $kwriteconfig_cmd --file kwinrc --group org.kde.kdecoration2 --key theme ""
    $kwriteconfig_cmd --file plasmarc --group Theme --key name "commonality"
    $kwriteconfig_cmd --file kdeglobals --group General --key ColorScheme "CDE"

    local cursor_theme
    cursor_theme="$(resolve_cursor_theme)"
    if [ "$cursor_theme" != "default" ]; then
        $kwriteconfig_cmd --file kcminputrc --group Mouse --key cursorTheme "$cursor_theme"
        $kwriteconfig_cmd --file kcminputrc --group Mouse --key cursorSize 24
    fi

    $kwriteconfig_cmd --file kdeglobals --group KDE --key LookAndFeelPackage "org.kde.cde.desktop"
    $kwriteconfig_cmd --file kscreenlockerrc --group Greeter --key LookAndFeel "org.kde.cde.desktop"

    echo "KDE configured to use CDE theme."
    echo
}

# Restart KDE components
restart_kde() {
    echo "Restarting KDE components..."

    if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        local qdbus_cmd=""
        for cmd in qdbus6 qdbus qdbus-qt6; do
            if command -v "$cmd" &>/dev/null; then
                qdbus_cmd="$cmd"
                break
            fi
        done
        if [ -n "$qdbus_cmd" ]; then
            "$qdbus_cmd" org.kde.KWin /KWin reconfigure 2>/dev/null || true
        fi
        if [ -n "$WAYLAND_DISPLAY" ] && pgrep -x plasmashell >/dev/null; then
            plasmashell --replace &>/dev/null &
        fi
        echo "Note: Log out and back in for full effect on Wayland."
    else
        if [ -n "$DISPLAY" ]; then
            if pgrep -x kwin_x11 >/dev/null; then
                kwin_x11 --replace &>/dev/null &
            fi
            if pgrep -x plasmashell >/dev/null; then
                plasmashell --replace &>/dev/null &
            fi
        fi
    fi

    sleep 2
    echo "Done!"
}

# Main
main() {
    check_deps
    install_kwin_decoration
    install_qt_style
    install_plasma_theme
    install_color_scheme
    install_cursor
    install_sddm_theme
    install_look_and_feel
    install_lockscreen

    echo
    if [ "$AUTO_YES" = true ]; then
        REPLY="y"
        echo "Configure KDE and SDDM to use CDE theme now? [Y/n] y (auto)"
    else
        read -p "Configure KDE and SDDM to use CDE theme now? [Y/n] " -n 1 -r
        echo
    fi
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        configure_kde
        restart_kde
    fi

    echo
    echo "=== Installation complete ==="
    echo
    echo "Plasma version: $PLASMA_VERSION"
    echo
    echo "Components installed:"
    echo "  - KWin window decoration"
    echo "  - Qt widget style"
    echo "  - Plasma desktop theme"
    echo "  - SDDM login theme"
    echo "  - Lock screen theme"
    echo "  - Color scheme"
    echo "  - Cursor theme"
    echo
    echo "Log saved to: $LOG_FILE"
    echo
}

main "$@"
