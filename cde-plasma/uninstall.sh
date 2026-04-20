#!/bin/bash
#
# CDE Plasma Theme Uninstaller
#

set -e

echo "=== CDE Plasma Theme Uninstaller ==="
echo

read -p "This will remove all CDE theme components. Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Detect Qt plugin directory
QT_PLUGIN_DIR="$(pkg-config --variable=plugindir Qt6Core 2>/dev/null || echo "")"

echo "Removing KWin decoration..."
# Qt6 / KDecoration3 paths (current)
for dir in "$QT_PLUGIN_DIR" /usr/lib/qt6/plugins /usr/lib/qt/plugins; do
    [ -z "$dir" ] && continue
    sudo rm -f "$dir/org.kde.kdecoration3/org.kde.cde.decoration.so" 2>/dev/null || true
    # Also clean up old misnamed variants
    sudo rm -f "$dir/org.kde.kdecoration3/kwin_cde_decoration.so" 2>/dev/null || true
    sudo rm -f "$dir/org.kde.kdecoration3/libkwin_cde_decoration.so" 2>/dev/null || true
done
# Legacy Qt5 / KDecoration2 paths (in case of old installs)
sudo rm -f /usr/lib/*/qt5/plugins/org.kde.kdecoration2/kwin_cde_decoration_kf5.so 2>/dev/null || true
sudo rm -f /usr/lib/*/qt5/plugins/org.kde.kdecoration2/kwin_cde_decoration.so 2>/dev/null || true

echo "Removing Qt style..."
for dir in "$QT_PLUGIN_DIR" /usr/lib/qt6/plugins /usr/lib/qt/plugins; do
    [ -z "$dir" ] && continue
    sudo rm -f "$dir/styles/cde_qt_style.so" 2>/dev/null || true
done
# Legacy Qt5 paths
sudo rm -f /usr/lib/*/qt5/plugins/styles/cde_qt_style_kf5.so 2>/dev/null || true
sudo rm -f /usr/lib/*/qt5/plugins/styles/cde_qt_style.so 2>/dev/null || true

echo "Removing Plasma theme..."
rm -rf ~/.local/share/plasma/desktoptheme/commonality 2>/dev/null || true

echo "Removing look-and-feel..."
rm -rf ~/.local/share/plasma/look-and-feel/org.kde.cde.desktop 2>/dev/null || true

echo "Removing SDDM theme..."
sudo rm -rf /usr/share/sddm/themes/sddm-cde 2>/dev/null || true
sudo rm -f /etc/sddm.conf.d/sddm-cde-theme.conf 2>/dev/null || true
sudo rm -f /etc/sddm.conf.d/cde-theme.conf 2>/dev/null || true
sudo rm -f /etc/systemd/system/sddm.service.d/cde-theme.conf 2>/dev/null || true
sudo systemctl daemon-reload 2>/dev/null || true

echo "Removing color scheme..."
rm -f ~/.local/share/color-schemes/CDE.colors 2>/dev/null || true

echo
echo "=== Uninstallation complete ==="
echo "Log out and back in to apply default themes."
echo
