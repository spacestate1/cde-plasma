#!/bin/bash
#
# Fix SDDM greeter for Qt6-only systems
# - Swaps sddm-greeter to use the Qt6 binary
# - Installs missing dependencies
# - Fixes cursor theme config
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo $0"
    exit 1
fi

echo "=== SDDM Qt6 Fixer ==="
echo

# 1. Install missing deps
echo "[1/3] Checking dependencies..."

missing=()

# qt6-declarative (provides the QML engine for sddm-greeter-qt6)
if ! pacman -Q qt6-declarative &>/dev/null; then
    missing+=(qt6-declarative)
fi

# cursor theme - use vanilla DMZ if available, otherwise skip
if [ ! -d /usr/share/icons/DMZ-Black ]; then
    if pacman -Si xcursor-vanilla-dmz &>/dev/null; then
        missing+=(xcursor-vanilla-dmz)
    fi
fi

if [ ${#missing[@]} -gt 0 ]; then
    echo "Installing: ${missing[*]}"
    pacman -S --noconfirm "${missing[@]}"
    echo "Done."
else
    echo "All dependencies present."
fi
echo

# 2. Swap greeter to Qt6
echo "[2/3] Switching sddm-greeter to Qt6..."

if [ ! -f /usr/bin/sddm-greeter-qt6 ]; then
    echo "ERROR: /usr/bin/sddm-greeter-qt6 not found."
    echo "Your sddm package may not ship a Qt6 greeter."
    exit 1
fi

# Check if already using Qt6
if [ -L /usr/bin/sddm-greeter ] && \
   [ "$(readlink /usr/bin/sddm-greeter)" = "sddm-greeter-qt6" ]; then
    echo "Already using Qt6 greeter."
else
    # Check if current greeter actually needs Qt5
    if ldd /usr/bin/sddm-greeter 2>/dev/null | grep -q "libQt5.*not found"; then
        echo "Current greeter has missing Qt5 libs — replacing."
    elif ldd /usr/bin/sddm-greeter 2>/dev/null | grep -q "libQt5"; then
        echo "Current greeter is Qt5 — replacing with Qt6."
    else
        echo "Current greeter appears fine, replacing anyway."
    fi

    mv /usr/bin/sddm-greeter /usr/bin/sddm-greeter-qt5.bak
    ln -s sddm-greeter-qt6 /usr/bin/sddm-greeter
    echo "Backed up Qt5 greeter to sddm-greeter-qt5.bak"
    echo "Linked sddm-greeter -> sddm-greeter-qt6"
fi
echo

# 3. Fix cursor theme in sddm config
echo "[3/3] Fixing cursor theme config..."

conf="/etc/sddm.conf.d/sddm-cde-theme.conf"
if [ -f "$conf" ]; then
    # Pick a cursor theme that actually exists
    if [ -d /usr/share/icons/DMZ-Black/cursors ]; then
        cursor="DMZ-Black"
    elif [ -d /usr/share/icons/Adwaita/cursors ]; then
        cursor="Adwaita"
    elif [ -d /usr/share/icons/breeze_cursors/cursors ]; then
        cursor="breeze_cursors"
    else
        cursor=""
    fi

    if [ -n "$cursor" ]; then
        sed -i "s/^CursorTheme=.*/CursorTheme=$cursor/" "$conf"
        echo "Set CursorTheme=$cursor in $conf"
    else
        sed -i '/^CursorTheme=/d' "$conf"
        echo "Removed CursorTheme (none installed)"
    fi
else
    echo "No sddm-cde-theme.conf found, skipping."
fi
echo

# Verify
echo "=== Verification ==="
echo -n "sddm-greeter: "
if [ -L /usr/bin/sddm-greeter ]; then
    echo "symlink -> $(readlink /usr/bin/sddm-greeter)"
else
    echo "regular binary"
fi

missing_libs=$(ldd /usr/bin/sddm-greeter 2>&1 | grep "not found" || true)
if [ -z "$missing_libs" ]; then
    echo "Libraries: all resolved"
else
    echo "Libraries: MISSING:"
    echo "$missing_libs"
    exit 1
fi

if [ -f "$conf" ]; then
    echo "SDDM config:"
    cat "$conf"
fi

echo
echo "=== Done ==="
echo "Restart SDDM to apply: sudo systemctl restart sddm"
echo "(This will drop you to the login screen)"
