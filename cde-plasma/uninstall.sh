#!/bin/bash
#
# CDE Plasma Theme Uninstaller
# Removes all CDE theme components and reverts KDE settings to Breeze defaults.
#

set -e
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STATE_LOCK_FILE="$RUNTIME_DIR/cde-plasma-install-${UID}.lock"

AUTO_YES=false
while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) AUTO_YES=true; shift ;;
        *) shift ;;
    esac
done

echo "=== CDE Plasma Theme Uninstaller ==="
echo

if [ "$AUTO_YES" = true ]; then
    REPLY="y"
    echo "Removing all CDE components and reverting to Breeze defaults... (auto-yes)"
else
    read -p "This will remove all CDE theme components and revert KDE to Breeze defaults. Continue? [y/N] " -n 1 -r
    echo
fi
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

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

# Pick whichever kwriteconfig is available (Plasma 6 first, then 5)
KWRITECONFIG=""
for cmd in kwriteconfig6 kwriteconfig5; do
    if command -v "$cmd" &>/dev/null; then
        KWRITECONFIG="$cmd"
        break
    fi
done

# Detect Qt plugin directory
QT_PLUGIN_DIR="$(pkg-config --variable=plugindir Qt6Core 2>/dev/null || echo "")"

# Location of the pre-install snapshot written by install.sh
SNAPSHOT_DIR="$HOME/.local/share/cde-plasma"
SNAPSHOT_FILE="$SNAPSHOT_DIR/pre-install.snapshot"

# -----------------------------------------------------------------------------
# 1. Revert KDE settings
#
# Preferred: replay the pre-install snapshot so the user lands on whatever
# values they had before installing CDE (custom color schemes, non-default
# cursor sizes, etc. are preserved).
#
# Fallback: if no snapshot exists (very old install, or snapshot lost), reset
# every key we know install.sh touched to Breeze defaults.
# -----------------------------------------------------------------------------
restore_kde_config_from_snapshot() {
    [ -f "$SNAPSHOT_FILE" ] || return 1
    [ -n "$KWRITECONFIG" ] || return 1

    echo "Restoring pre-install KDE settings from snapshot..."

    local file group key state val
    while IFS=$'\t' read -r file group key state val; do
        [ -z "$file" ] && continue
        case "$state" in
            UNSET)
                $KWRITECONFIG --file "$file" --group "$group" --key "$key" --delete 2>/dev/null || true
                ;;
            SET)
                $KWRITECONFIG --file "$file" --group "$group" --key "$key" "$val" 2>/dev/null || true
                ;;
        esac
    done < "$SNAPSHOT_FILE"

    rm -f "$SNAPSHOT_FILE"
    rmdir "$SNAPSHOT_DIR" 2>/dev/null || true
    echo "Pre-install settings restored."
    return 0
}

reset_kde_config_to_breeze_defaults() {
    echo "Reverting KDE settings to Breeze defaults..."
    if [ -z "$KWRITECONFIG" ]; then
        echo "  kwriteconfig not found; skipping KDE config revert. Reset manually in System Settings."
        return
    fi

    # Widget style
    $KWRITECONFIG --file kdeglobals --group KDE --key widgetStyle "Breeze" 2>/dev/null || true

    # Window decoration (same group name is used in Plasma 5 and 6)
    $KWRITECONFIG --file kwinrc --group org.kde.kdecoration2 --key library "org.kde.breeze" 2>/dev/null || true
    $KWRITECONFIG --file kwinrc --group org.kde.kdecoration2 --key theme "Breeze" 2>/dev/null || true

    # Plasma desktop theme
    $KWRITECONFIG --file plasmarc --group Theme --key name "default" 2>/dev/null || true

    # Color scheme
    $KWRITECONFIG --file kdeglobals --group General --key ColorScheme "BreezeLight" 2>/dev/null || true

    # Look-and-feel package
    $KWRITECONFIG --file kdeglobals --group KDE --key LookAndFeelPackage "org.kde.breeze.desktop" 2>/dev/null || true

    # Remove the lock-screen look-and-feel override entirely so the Greeter
    # falls back to the global LookAndFeelPackage (Breeze).
    $KWRITECONFIG --file kscreenlockerrc --group Greeter --key LookAndFeel --delete 2>/dev/null || true
    $KWRITECONFIG --file kscreenlockerrc --group Greeter --key Theme --delete 2>/dev/null || true

    # Cursor theme — prefer breeze_cursors, fall back to Adwaita if not installed
    if [ -d /usr/share/icons/breeze_cursors/cursors ]; then
        $KWRITECONFIG --file kcminputrc --group Mouse --key cursorTheme "breeze_cursors" 2>/dev/null || true
    elif [ -d /usr/share/icons/Adwaita/cursors ]; then
        $KWRITECONFIG --file kcminputrc --group Mouse --key cursorTheme "Adwaita" 2>/dev/null || true
    fi

    # Drop the cursor size install.sh forced to 24 so KDE uses its own default
    $KWRITECONFIG --file kcminputrc --group Mouse --key cursorSize --delete 2>/dev/null || true

    # Drop the Wayland input-method override install.sh set to "" and the
    # virtual-keyboard disable flag so Plasma uses its defaults.
    $KWRITECONFIG --file kwinrc --group Wayland --key InputMethod --delete 2>/dev/null || true
    $KWRITECONFIG --file kcmvirtualkeyboardrc --group General --key VirtualKeyboardEnabled --delete 2>/dev/null || true
}

if ! restore_kde_config_from_snapshot; then
    reset_kde_config_to_breeze_defaults
fi

# -----------------------------------------------------------------------------
# 2. Remove CDE plugins (system-wide, needs sudo)
# -----------------------------------------------------------------------------
echo "Removing KWin decoration..."
# Qt6 / KDecoration3 paths (current)
for dir in "$QT_PLUGIN_DIR" /usr/lib/qt6/plugins /usr/lib/qt/plugins; do
    [ -z "$dir" ] && continue
    sudo rm -f "$dir/org.kde.kdecoration3/org.kde.cde.decoration.so" 2>/dev/null || true
    sudo rm -f "$dir/org.kde.kdecoration3/kwin_cde_decoration.so" 2>/dev/null || true
    sudo rm -f "$dir/org.kde.kdecoration3/libkwin_cde_decoration.so" 2>/dev/null || true
    # KCM (decoration config-UI) plugin, installed alongside by the Qt6 build
    sudo rm -f "$dir/org.kde.kdecoration3.kcm/kcm_cdedecoration.so" 2>/dev/null || true
done
# Qt5 / KDecoration2 paths. The current P5 build names the .so after the
# plugin Id (org.kde.cde.decoration.so) so kscreenlocker's per-decoration
# KCM lookup works; older installs used kwin_cde_decoration_kf5.so and
# shipped a separate kcm_cdedecoration_kf5.so in ...kdecoration2.kcm/.
# Clean up all of them.
sudo rm -f /usr/lib/*/qt5/plugins/org.kde.kdecoration2/org.kde.cde.decoration.so 2>/dev/null || true
sudo rm -f /usr/lib/*/qt5/plugins/org.kde.kdecoration2/kwin_cde_decoration_kf5.so 2>/dev/null || true
sudo rm -f /usr/lib/*/qt5/plugins/org.kde.kdecoration2/libkwin_cde_decoration_kf5.so 2>/dev/null || true
sudo rm -f /usr/lib/*/qt5/plugins/org.kde.kdecoration2/kwin_cde_decoration.so 2>/dev/null || true
sudo rm -f /usr/lib/*/qt5/plugins/org.kde.kdecoration2.kcm/kcm_cdedecoration_kf5.so 2>/dev/null || true
sudo rm -f /usr/lib/*/qt5/plugins/org.kde.kdecoration2.kcm/libkcm_cdedecoration_kf5.so 2>/dev/null || true
sudo rmdir /usr/lib/*/qt5/plugins/org.kde.kdecoration2.kcm 2>/dev/null || true

echo "Removing Qt style..."
for dir in "$QT_PLUGIN_DIR" /usr/lib/qt6/plugins /usr/lib/qt/plugins; do
    [ -z "$dir" ] && continue
    sudo rm -f "$dir/styles/cde_qt_style.so" 2>/dev/null || true
done
sudo rm -f /usr/lib/*/qt5/plugins/styles/cde_qt_style_kf5.so 2>/dev/null || true
sudo rm -f /usr/lib/*/qt5/plugins/styles/cde_qt_style.so 2>/dev/null || true

# -----------------------------------------------------------------------------
# 3. Remove user-local theme data
# -----------------------------------------------------------------------------
echo "Removing Plasma themes..."
rm -rf ~/.local/share/plasma/desktoptheme/commonality 2>/dev/null || true
rm -rf ~/.local/share/plasma/desktoptheme/commonality-dark 2>/dev/null || true

echo "Removing look-and-feel..."
rm -rf ~/.local/share/plasma/look-and-feel/org.kde.cde.desktop 2>/dev/null || true
rm -rf ~/.local/share/plasma/look-and-feel/org.kde.cde-dark.desktop 2>/dev/null || true

echo "Removing color schemes..."
rm -f ~/.local/share/color-schemes/CDE.colors 2>/dev/null || true
rm -f ~/.local/share/color-schemes/CDE-Dark.colors 2>/dev/null || true
rm -f ~/.local/share/color-schemes/CDE-Chartreuse.colors 2>/dev/null || true
rm -f ~/.local/share/color-schemes/CDE-ElectricPink.colors 2>/dev/null || true

# Per-user CDE decoration color config (Frame/ActiveTitle/etc.). Written by
# the CDE look-and-feel's `defaults` file on apply, and by the decoration's
# Configure dialog. Only a CDE install uses this file, so it's safe to drop.
rm -f ~/.config/cdedecoration 2>/dev/null || true

# -----------------------------------------------------------------------------
# 4. Restore the original system lock screen
# -----------------------------------------------------------------------------
LOCKSCREEN_DIR="/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen"
BACKUP_DIR="${LOCKSCREEN_DIR}.breeze-backup"

if [ -f "$BACKUP_DIR/LockScreenUi.qml" ]; then
    echo "Restoring original lock screen from backup..."
    sudo cp "$BACKUP_DIR/LockScreenUi.qml" "$LOCKSCREEN_DIR/LockScreenUi.qml"
    # Also restore any other files that were in the original backup, in case a
    # future installer variant touched more than LockScreenUi.qml.
    sudo cp -rn "$BACKUP_DIR"/. "$LOCKSCREEN_DIR"/ 2>/dev/null || true
    sudo rm -rf "$BACKUP_DIR"
    echo "Original lock screen restored."
elif [ -d "$BACKUP_DIR" ]; then
    echo "WARNING: $BACKUP_DIR exists but LockScreenUi.qml is missing from it."
    echo "         Not attempting restore. Backup left in place."
else
    echo "No lock screen backup found."
    echo "  If the CDE lock screen is still active, reinstall the plasma-workspace"
    echo "  (Arch/Fedora) or plasma-desktop (Debian/Ubuntu) package to restore it."
fi

# -----------------------------------------------------------------------------
# 5. Remove SDDM theme, config drop-in, and systemd override
# -----------------------------------------------------------------------------
echo "Removing SDDM theme..."
sudo rm -rf /usr/share/sddm/themes/sddm-cde 2>/dev/null || true
sudo rm -f /etc/sddm.conf.d/sddm-cde-theme.conf 2>/dev/null || true
sudo rm -f /etc/sddm.conf.d/cde-theme.conf 2>/dev/null || true
sudo rm -f /etc/systemd/system/sddm.service.d/cde-theme.conf 2>/dev/null || true
# Remove the drop-in dir only if it's now empty (don't clobber other overrides)
sudo rmdir /etc/systemd/system/sddm.service.d 2>/dev/null || true

if command -v systemctl &>/dev/null; then
    sudo systemctl daemon-reload 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 6. Remove the system cursor-default inheritance that install.sh wrote
# -----------------------------------------------------------------------------
# install.sh writes /usr/share/icons/default/index.theme without backing it up.
# Only remove it if it references a CDE cursor, so we don't wipe a file owned
# by a distro package.
if [ -f /usr/share/icons/default/index.theme ]; then
    if grep -qE '^Inherits=(Hackneyed|LHackneyed|Vanilla-DMZ|DMZ-Black)' /usr/share/icons/default/index.theme 2>/dev/null; then
        echo "Removing CDE cursor inheritance file..."
        sudo rm -f /usr/share/icons/default/index.theme
        sudo rmdir /usr/share/icons/default 2>/dev/null || true
    fi
fi

# -----------------------------------------------------------------------------
# 7. Reload KDE so the revert takes effect without a full re-login
# -----------------------------------------------------------------------------
echo "Reloading KDE components..."

if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    for cmd in qdbus6 qdbus qdbus-qt6; do
        if command -v "$cmd" &>/dev/null; then
            "$cmd" org.kde.KWin /KWin reconfigure 2>/dev/null || true
            break
        fi
    done
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

echo
echo "=== Uninstallation complete ==="
echo "KDE has been reverted to Breeze defaults."
echo "Log out and back in to fully apply the defaults."
echo
