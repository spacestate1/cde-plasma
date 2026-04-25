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
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STATE_LOCK_FILE="$RUNTIME_DIR/cde-plasma-install-${UID}.lock"

# Snapshot of pre-install KDE config values — uninstall.sh reads this to
# restore the user's prior settings (rather than clobbering them with stock
# Breeze values).
SNAPSHOT_DIR="$HOME/.local/share/cde-plasma"
SNAPSHOT_FILE="$SNAPSHOT_DIR/pre-install.snapshot"

# Send all output to both terminal and timestamped log file.
exec > >(while IFS= read -r line; do
    printf '%s\n' "$line"
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line" >> "$LOG_FILE"
done) 2>&1

echo "=== CDE Plasma Theme Installer ==="
echo "Log file: $LOG_FILE"
echo

acquire_state_lock() {
    exec 9>"$STATE_LOCK_FILE"
    if command -v flock &>/dev/null; then
        flock 9
        return
    fi

    echo "ERROR: flock not found; cannot safely serialize install/uninstall operations." >&2
    exit 1
}

acquire_state_lock

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

# Build the prebuilt target identifier used to pick a bundled tarball.
# Shape: <distro>-plasma<N>-<arch>, e.g. arch-plasma6-x86_64.
# Distro is part of the key because plugin paths differ across families
# (Debian uses multi-arch /usr/lib/x86_64-linux-gnu/qt6/plugins, Arch/Fedora
# use /usr/lib/qt6/plugins), and the tarball's staging tree was cut by the
# build-host's CMake — it only lands correctly on the same family.
detect_target() {
    local distro arch
    distro="$(detect_distro)"
    arch="$(uname -m)"
    echo "${distro}-plasma${PLASMA_VERSION}-${arch}"
}

PREBUILT_DIR="$SCRIPT_DIR/prebuilt"

prebuilt_member_is_safe() {
    local rel="$1"

    case "$rel" in
        ./usr|./usr/*) ;;
        *)
            return 1
            ;;
    esac

    case "$rel" in
        *"/../"*|../*|*/..|*"/..")
            return 1
            ;;
    esac

    return 0
}

validate_prebuilt_tarball() {
    local tarball="$1" rel

    while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        if ! prebuilt_member_is_safe "$rel"; then
            echo "  ERROR: refusing unsafe prebuilt archive member: $rel"
            return 1
        fi
    done < <(tar tzf "$tarball")

    return 0
}

# Check a just-extracted .so for unresolved libraries. A prebuilt cut against
# a slightly different Qt/KF ABI typically leaves "not found" entries in ldd
# output — we'd rather catch that now than have KWin silently refuse to load
# the decoration at runtime.
prebuilt_so_looks_ok() {
    local so="$1"
    if ! command -v ldd &>/dev/null; then
        return 0   # can't check; assume ok
    fi
    if ldd "$so" 2>/dev/null | grep -q 'not found'; then
        echo "  WARN: $so has unresolved libraries:"
        ldd "$so" 2>/dev/null | grep 'not found' | sed 's/^/    /'
        return 1
    fi
    return 0
}

# Try to install the two compiled plugins from a prebuilt tarball matching
# the current target. Returns 0 on success, non-zero if no tarball matched
# or the extracted plugins failed the sanity check.
try_install_prebuilt() {
    local target tarball
    target="$(detect_target)"
    tarball="$PREBUILT_DIR/cde-plasma-${target}.tar.gz"

    if [ ! -f "$tarball" ]; then
        echo "  No prebuilt tarball for target '$target' — will build from source."
        return 1
    fi

    echo "  Found prebuilt: $tarball"
    if ! validate_prebuilt_tarball "$tarball"; then
        echo "  Unsafe prebuilt tarball contents detected — will build from source."
        return 1
    fi
    echo "  Extracting to / (requires sudo)..."
    if ! sudo tar xzf "$tarball" -C / --no-same-owner --no-same-permissions; then
        echo "  Extract failed — will build from source."
        return 1
    fi

    # Verify the .so files that were just laid down still resolve.
    # The tarball lists its own contents; we re-run ldd on each one after
    # install so Qt/KF ABI drift gets caught before we declare victory.
    local bad=0 rel abs
    while IFS= read -r rel; do
        case "$rel" in
            *.so)
                abs="/$rel"
                if [ -f "$abs" ] && ! prebuilt_so_looks_ok "$abs"; then
                    bad=1
                fi
                ;;
        esac
    done < <(tar tzf "$tarball" | sed 's|^\./||')

    if [ "$bad" = "1" ]; then
        echo "  Prebuilt plugins failed ldd check — removing and falling back to source build."
        # Roll back: re-list the tarball and delete every file it placed.
        while IFS= read -r rel; do
            if ! prebuilt_member_is_safe "$rel"; then
                continue
            fi
            abs="/${rel#./}"
            case "$abs" in
                *.so)
                    ;;
                *)
                    continue
                    ;;
            esac
            if [ -f "$abs" ]; then
                sudo rm -f "$abs"
            fi
        done < <(tar tzf "$tarball")
        return 1
    fi

    echo "  Prebuilt plugins installed cleanly."
    return 0
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
                kconfigwidgets kcmutils kwidgetsaddons \
                curl
            ;;
        debian)
            echo "Installing dependencies via apt..."
            sudo apt-get update -qq
            sudo apt-get install -y \
                cmake make g++ pkg-config \
                qtbase5-dev qtbase5-dev-tools \
                extra-cmake-modules \
                libkf5coreaddons-dev libkf5config-dev libkf5configwidgets-dev \
                libkf5kcmutils-dev libkf5widgetsaddons-dev \
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
                kf5-kcoreaddons-devel kf5-kconfig-devel kf5-kconfigwidgets-devel \
                kf5-kcmutils-devel kf5-kwidgetsaddons-devel \
                kdecoration-devel \
                curl
            ;;
        *)
            echo "Unknown distro. Please install manually:"
            echo "  cmake, g++, pkg-config, Qt5, extra-cmake-modules,"
            echo "  KF5 CoreAddons, Config, ConfigWidgets, KCMUtils, WidgetsAddons, KDecoration2"
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

# Return 0 if CMake config for $1 (e.g. KF5ConfigWidgets) exists in any of the
# standard prefixes across Debian/Ubuntu (multi-arch), Arch, Fedora.
have_cmake_pkg() {
    local pkg="$1"
    local base f
    for base in /usr/lib/x86_64-linux-gnu/cmake /usr/lib/aarch64-linux-gnu/cmake \
                /usr/lib/cmake /usr/lib64/cmake /usr/local/lib/cmake; do
        for f in "$base/$pkg/${pkg}Config.cmake" "$base/$pkg/$(echo "$pkg" | tr '[:upper:]' '[:lower:]')-config.cmake"; do
            [ -f "$f" ] && return 0
        done
    done
    return 1
}

# Check for required build dependencies
check_deps() {
    local need_install=false
    local required_cmake_pkgs

    if [ "$PLASMA_VERSION" = "5" ]; then
        required_cmake_pkgs=(KF5CoreAddons KF5Config KF5ConfigWidgets KF5KCMUtils KF5WidgetsAddons KDecoration2)
    else
        required_cmake_pkgs=(KF6CoreAddons KF6Config KF6ConfigWidgets KF6KCMUtils KF6WidgetsAddons KDecoration3)
    fi

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

    local pkg
    for pkg in "${required_cmake_pkgs[@]}"; do
        if ! have_cmake_pkg "$pkg"; then
            echo "Missing: $pkg development package"
            need_install=true
        fi
    done

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

        for pkg in "${required_cmake_pkgs[@]}"; do
            if ! have_cmake_pkg "$pkg"; then
                echo "ERROR: $pkg still missing after install attempt."
                exit 1
            fi
        done

        echo "All dependencies installed."
    else
        echo "All dependencies present."
    fi
    echo
}

# Pick a safe -j value for make. Each Qt6 + KF6 compile unit can peak around
# 500 MB–1 GB of RAM, so parallelism is capped by (available RAM + swap) / 1 GB,
# not just nproc. On low-memory systems (e.g. a 2 GB VM with Plasma running and
# no swap) this drops to -j1 to avoid kswapd thrashing / OOM.
compute_make_jobs() {
    local nproc_jobs mem_avail_kb swap_kb budget_mb mem_per_job=1024 jobs
    nproc_jobs="$(nproc 2>/dev/null || echo 1)"

    mem_avail_kb="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
    swap_kb="$(awk '/^SwapFree:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
    budget_mb=$(( (mem_avail_kb + swap_kb) / 1024 ))

    if [ "$budget_mb" -lt "$mem_per_job" ]; then
        jobs=1
    else
        jobs=$(( budget_mb / mem_per_job ))
        [ "$jobs" -gt "$nproc_jobs" ] && jobs="$nproc_jobs"
    fi
    [ "$jobs" -lt 1 ] && jobs=1

    # Warn if we're clearly memory-starved so the user can add swap.
    if [ "$jobs" = "1" ] && [ "$budget_mb" -lt 768 ] && [ "$swap_kb" = "0" ]; then
        echo "  WARNING: only ${budget_mb} MB RAM available and no swap." >&2
        echo "  Even -j1 may OOM during a Qt6 compile. Consider adding a swap file:" >&2
        echo "    sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile" >&2
        echo "    sudo mkswap /swapfile && sudo swapon /swapfile" >&2
    fi

    echo "$jobs"
}

# Install the two compiled plugins — prefers a prebuilt tarball matching
# the current distro/Plasma/arch, falls back to a full source build (with
# toolchain install) only when no prebuilt matches or the one we have
# fails its ABI sanity check.
install_compiled_components() {
    echo "[1-2/8] Installing compiled plugins (KWin decoration + Qt style)..."

    if try_install_prebuilt; then
        echo "Compiled plugins installed from prebuilt."
        echo
        return
    fi

    echo "  Will build from source. Checking toolchain..."
    check_deps
    install_kwin_decoration
    install_qt_style
}

# Build and install KWin decoration
install_kwin_decoration() {
    echo "[1/8] Building KWin decoration..."

    local src_dir
    if [ "$PLASMA_VERSION" = "5" ]; then
        src_dir="$SCRIPT_DIR/kwin_cde_decoration_kf5_plasma5"
        echo "  Using Plasma 5 (KF5/KDecoration2) source..."
    else
        src_dir="$SCRIPT_DIR/kwin_cde_decoration_kf6_plasma6"
        echo "  Using Plasma 6 (KF6/KDecoration3) source..."
    fi

    cd "$src_dir"
    rm -rf build && mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release
    local jobs
    jobs="$(compute_make_jobs)"
    echo "  Building with make -j${jobs} (capped by available RAM + swap)"
    make -j"$jobs"
    echo "Installing KWin decoration (requires sudo)..."
    sudo make install

    # Clean up old misnamed plugins left by previous installs
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
    else
        # On P5 we renamed the decoration target to org.kde.cde.decoration
        # (OUTPUT_NAME) so kscreenlocker's per-decoration KCM lookup works.
        # Any previous install left kwin_cde_decoration_kf5.so behind;
        # remove it so kwin doesn't load two copies.
        local plugin_dir
        plugin_dir="$(pkg-config --variable=plugindir Qt5Core 2>/dev/null || echo /usr/lib/x86_64-linux-gnu/qt5/plugins)"
        for old in "$plugin_dir/org.kde.kdecoration2/kwin_cde_decoration_kf5.so" \
                   "$plugin_dir/org.kde.kdecoration2/libkwin_cde_decoration_kf5.so" \
                   "$plugin_dir/org.kde.kdecoration2.kcm/kcm_cdedecoration_kf5.so" \
                   "$plugin_dir/org.kde.kdecoration2.kcm/libkcm_cdedecoration_kf5.so"; do
            if [ -f "$old" ]; then
                echo "  Removing old P5 plugin: $old"
                sudo rm -f "$old"
            fi
        done
        # And if the old separate-KCM namespace dir is now empty, clean it up.
        sudo rmdir "$plugin_dir/org.kde.kdecoration2.kcm" 2>/dev/null || true
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
        src_dir="$SCRIPT_DIR/cde_qt_style_kf6_plasma6"
        echo "  Using Qt6 style source..."
    fi

    cd "$src_dir"
    rm -rf build && mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release
    local jobs
    jobs="$(compute_make_jobs)"
    echo "  Building with make -j${jobs} (capped by available RAM + swap)"
    make -j"$jobs"
    echo "Installing Qt style (requires sudo)..."
    sudo make install
    echo "Qt widget style installed."
    echo
}

# Install Plasma desktop themes (light + dark)
install_plasma_theme() {
    echo "[3/8] Installing Plasma themes..."
    local base_dir="$HOME/.local/share/plasma/desktoptheme"
    mkdir -p "$base_dir/commonality" "$base_dir/commonality-dark"
    cp -r "$SCRIPT_DIR/commonality/"* "$base_dir/commonality/"
    cp -r "$SCRIPT_DIR/commonality-dark/"* "$base_dir/commonality-dark/"
    echo "Plasma themes installed to $base_dir (commonality + commonality-dark)"
    echo
}

# Install color schemes
install_color_scheme() {
    echo "[4/8] Installing color schemes..."
    local colors_dir="$HOME/.local/share/color-schemes"
    mkdir -p "$colors_dir"
    cp "$SCRIPT_DIR/CDE.colors" "$colors_dir/"
    cp "$SCRIPT_DIR/CDE-Dark.colors" "$colors_dir/"
    cp "$SCRIPT_DIR/CDE-Chartreuse.colors" "$colors_dir/"
    cp "$SCRIPT_DIR/CDE-ElectricPink.colors" "$colors_dir/"
    echo "Color schemes installed to $colors_dir (Blue-Gray, Dark, Chartreuse, Electric Pink)"
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
    # [General] InputMethod= (empty) disables the Qt virtual keyboard at the
    # SDDM greeter, matching the no-OSK behavior we set in the user session.
    sudo tee /etc/sddm.conf.d/sddm-cde-theme.conf > /dev/null << EOF
[Theme]
Current=sddm-cde
CursorTheme=$sddm_cursor

[General]
InputMethod=
EOF

    if has_systemd; then
        sudo mkdir -p /etc/systemd/system/sddm.service.d
        sudo tee /etc/systemd/system/sddm.service.d/cde-theme.conf > /dev/null << EOF
[Service]
ExecStartPre=/bin/sh -c '[ -f /etc/sddm.conf.d/sddm-cde-theme.conf ] || printf "[Theme]\nCurrent=sddm-cde\nCursorTheme=$sddm_cursor\n\n[General]\nInputMethod=\n" > /etc/sddm.conf.d/sddm-cde-theme.conf'
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
    cp -r "$SCRIPT_DIR/look-and-feel/org.kde.cde-dark.desktop" "$laf_dir/"
    echo "Look-and-feel theme installed."
    echo
}

# Install CDE lock screen
install_lockscreen() {
    echo "[8/8] Installing CDE lock screen..."

    # Plasma 5 and Plasma 6 deliver the lock screen QML through different
    # paths. On P5 it lives inside the look-and-feel package; on P6 it's
    # delivered via the shell's lockscreen dir. Handle both.
    if [ "$PLASMA_VERSION" = "5" ]; then
        # The look-and-feel package step already copied our P5 QML to the
        # per-user dir. Nothing more to do — this is the active lock screen
        # source as long as kscreenlockerrc points at org.kde.cde.desktop.
        local laf_lock="$HOME/.local/share/plasma/look-and-feel/org.kde.cde.desktop/contents/lockscreen/LockScreenUi.qml"
        if [ -f "$laf_lock" ]; then
            echo "  CDE lock screen provided by look-and-feel package ($laf_lock)."
        else
            echo "  WARNING: expected $laf_lock not found — look-and-feel install may have failed."
        fi
        echo
        return
    fi

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

# Snapshot the current values of every KDE config key we're about to modify.
# uninstall.sh replays this to put the user back exactly where they were.
# If a snapshot already exists (re-install scenario), we leave it alone — the
# existing snapshot reflects the true pre-install state, not the current
# CDE-applied state.
snapshot_kde_config() {
    local kreadconfig="kreadconfig6"
    if [ "$PLASMA_VERSION" = "5" ]; then
        kreadconfig="kreadconfig5"
    fi

    if ! command -v "$kreadconfig" &>/dev/null; then
        echo "  $kreadconfig not found — skipping pre-install snapshot."
        echo "  (uninstall.sh will fall back to Breeze defaults)"
        return
    fi

    if [ -f "$SNAPSHOT_FILE" ]; then
        echo "  Pre-install snapshot already exists — not overwriting."
        return
    fi

    # If CDE already looks applied, the "current state" is not a genuine
    # pre-install snapshot — capturing it would make uninstall a no-op.
    local cur_style cur_decor
    cur_style="$("$kreadconfig" --file kdeglobals --group KDE --key widgetStyle 2>/dev/null || echo "")"
    cur_decor="$("$kreadconfig" --file kwinrc --group org.kde.kdecoration2 --key library 2>/dev/null || echo "")"
    if [ "$cur_style" = "cde" ] || [ "$cur_decor" = "org.kde.cde.decoration" ]; then
        echo "  CDE already active — skipping snapshot to avoid capturing CDE state."
        echo "  (uninstall.sh will fall back to Breeze defaults)"
        return
    fi

    mkdir -p "$SNAPSHOT_DIR"
    local sentinel="__CDE_UNSET_SENTINEL_$$__"
    local tmp
    tmp="$(mktemp "$SNAPSHOT_DIR/pre-install.snapshot.XXXXXX")"

    # Every (file, group, key) tuple configure_kde() writes below.
    local entries=(
        "kdeglobals|KDE|widgetStyle"
        "kwinrc|org.kde.kdecoration2|library"
        "kwinrc|org.kde.kdecoration2|theme"
        "plasmarc|Theme|name"
        "kdeglobals|General|ColorScheme"
        "kcminputrc|Mouse|cursorTheme"
        "kcminputrc|Mouse|cursorSize"
        "kdeglobals|KDE|LookAndFeelPackage"
        "kscreenlockerrc|Greeter|LookAndFeel"
        "kscreenlockerrc|Greeter|Theme"
        "kwinrc|Wayland|InputMethod"
        "kcmvirtualkeyboardrc|General|VirtualKeyboardEnabled"
    )

    local entry file group key val
    for entry in "${entries[@]}"; do
        IFS='|' read -r file group key <<< "$entry"
        val="$("$kreadconfig" --file "$file" --group "$group" --key "$key" --default "$sentinel" 2>/dev/null)" || val="$sentinel"
        if [ "$val" = "$sentinel" ]; then
            printf '%s\t%s\t%s\tUNSET\t\n' "$file" "$group" "$key" >> "$tmp"
        else
            printf '%s\t%s\t%s\tSET\t%s\n' "$file" "$group" "$key" "$val" >> "$tmp"
        fi
    done

    mv "$tmp" "$SNAPSHOT_FILE"
    echo "  Pre-install settings snapshotted to $SNAPSHOT_FILE"
}

# Configure KDE to use the theme
configure_kde() {
    echo "Configuring KDE settings..."

    snapshot_kde_config

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
    # Plasma 5's kscreenlocker_greet reads [Greeter] Theme; Plasma 6 reads
    # [Greeter] LookAndFeel. Write both so the same script works on both.
    $kwriteconfig_cmd --file kscreenlockerrc --group Greeter --key LookAndFeel "org.kde.cde.desktop"
    $kwriteconfig_cmd --file kscreenlockerrc --group Greeter --key Theme "org.kde.cde.desktop"

    # Disable on-screen / virtual keyboard. CDE predates touchscreens; the OSK
    # popping up over text fields breaks the aesthetic.
    $kwriteconfig_cmd --file kwinrc --group Wayland --key InputMethod ""
    $kwriteconfig_cmd --file kcmvirtualkeyboardrc --group General --key VirtualKeyboardEnabled "false"

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
    install_compiled_components
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
