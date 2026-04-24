#!/bin/bash
#
# make-prebuilt.sh — build the compiled plugins and stage them into a
# redistributable tarball so end users can `install.sh` without a toolchain.
#
# Output: prebuilt/cde-plasma-<distro>-plasma<N>-<arch>.tar.gz
# Layout: DESTDIR staging tree (./usr/lib/.../plugin.so) so `tar xzf -C /`
# drops files at the same paths CMake chose on this build host.
#
# Run this on each target distro you want to ship for. Example matrix:
#   - Arch   + Plasma 6  (x86_64)
#   - Ubuntu + Plasma 6  (x86_64, multi-arch plugin dir)
#   - Fedora + Plasma 6  (x86_64)
# and optionally the Plasma 5 variants on their respective older distros.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$REPO_DIR/prebuilt"
mkdir -p "$OUT_DIR"

# --- detect distro family (mirrors install.sh) ---
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            arch|manjaro|endeavouros|garuda|cachyos) echo "arch" ;;
            ubuntu|debian|linuxmint|pop|elementary|zorin) echo "debian" ;;
            fedora|rhel|centos|rocky|alma|nobara) echo "fedora" ;;
            *)
                case "$ID_LIKE" in
                    *arch*)            echo "arch" ;;
                    *debian*|*ubuntu*) echo "debian" ;;
                    *fedora*|*rhel*)   echo "fedora" ;;
                    *)                 echo "unknown" ;;
                esac
                ;;
        esac
    else
        echo "unknown"
    fi
}

# --- detect Plasma 5 vs 6 (mirrors install.sh) ---
detect_plasma_version() {
    if [ -d /usr/include/KDecoration2 ]; then
        echo 5; return
    fi
    if [ -d /usr/include/KF6/KDecoration3 ] || [ -d /usr/include/kdecoration3 ]; then
        echo 6; return
    fi
    if command -v plasmashell &>/dev/null; then
        local v
        v=$(plasmashell --version 2>/dev/null | grep -oP '\d+' | head -1 || echo 6)
        echo "$v"; return
    fi
    echo 6
}

DISTRO="$(detect_distro)"
PLASMA_VERSION="$(detect_plasma_version)"
ARCH="$(uname -m)"
TARGET="${DISTRO}-plasma${PLASMA_VERSION}-${ARCH}"

echo "=== cde-plasma prebuilt builder ==="
echo "Target: $TARGET"
echo "Output: $OUT_DIR/cde-plasma-${TARGET}.tar.gz"
echo

if [ "$DISTRO" = "unknown" ]; then
    echo "ERROR: unknown distro — cannot tag a reliable tarball name." >&2
    exit 1
fi

# --- pick sources that match Plasma version ---
if [ "$PLASMA_VERSION" = "5" ]; then
    DECO_SRC="$REPO_DIR/kwin_cde_decoration_kf5_plasma5"
    STYLE_SRC="$REPO_DIR/cde_qt_style_kf5_plasma5"
else
    DECO_SRC="$REPO_DIR/kwin_cde_decoration_kf6_plasma6"
    STYLE_SRC="$REPO_DIR/cde_qt_style_kf6_plasma6"
fi

STAGE_DIR="$(mktemp -d -t cde-prebuilt-stage-XXXXXX)"
trap 'rm -rf "$STAGE_DIR"' EXIT

build_and_stage() {
    local name="$1" src="$2"
    echo "--- Building $name ---"
    (
        cd "$src"
        rm -rf build
        mkdir build
        cd build
        cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
        make -j"$(nproc 2>/dev/null || echo 2)"
        make install DESTDIR="$STAGE_DIR"
    )
    echo
}

build_and_stage "KWin decoration" "$DECO_SRC"
build_and_stage "Qt widget style"  "$STYLE_SRC"

# Sanity: the staging tree must contain at least one .so.
SO_COUNT="$(find "$STAGE_DIR" -name '*.so' | wc -l)"
if [ "$SO_COUNT" -lt 2 ]; then
    echo "ERROR: staging tree only has $SO_COUNT .so files, expected >=2." >&2
    echo "Inspect $STAGE_DIR" >&2
    trap - EXIT
    exit 1
fi

echo "Staged files:"
(cd "$STAGE_DIR" && find . -type f | sort)
echo

# --- pack ---
OUT_TAR="$OUT_DIR/cde-plasma-${TARGET}.tar.gz"
# tar the contents of the staging dir so paths start with ./usr/...
tar czf "$OUT_TAR" -C "$STAGE_DIR" .

SIZE="$(du -h "$OUT_TAR" | cut -f1)"
echo "=== Done ==="
echo "Wrote $OUT_TAR ($SIZE)"
echo
echo "To test install from this tarball:"
echo "  sudo tar tzf $OUT_TAR   # list"
echo "  sudo tar xzf $OUT_TAR -C /   # install"
echo
echo "install.sh will pick it up automatically on a matching target."
