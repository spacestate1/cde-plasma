#!/bin/bash
#
# build-arch.sh VERSION — build cde-plasma .pkg.tar.zst for Arch Linux.
#
# Self-contained: creates a local source tarball from the current repo
# checkout, points PKGBUILD at it, runs makepkg. Output goes to dist/.
#
# Used by CI (.github/workflows/release.yml) and runnable locally:
#   bash cde-plasma/packaging/build-arch.sh 0.1.0

set -euo pipefail

VERSION="${1:-0.0.0-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
WORK_DIR="$(mktemp -d -t cde-arch-build-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$DIST_DIR"

echo "=== Arch build: cde-plasma $VERSION ==="

# Stage a clean source tree matching what GitHub's tarball would look like:
# top dir cde-plasma-VERSION/ with the repo contents inside.
SRC_TOP="cde-plasma-$VERSION"
mkdir -p "$WORK_DIR/$SRC_TOP"
rsync -a \
    --exclude='.git' \
    --exclude='build' \
    --exclude='build-*/' \
    --exclude='dist' \
    --exclude='prebuilt/*.tar.gz' \
    "$REPO_ROOT/" "$WORK_DIR/$SRC_TOP/"

# Tar it up. PKGBUILD's source=() expects this exact filename.
tar czf "$WORK_DIR/cde-plasma-$VERSION.tar.gz" -C "$WORK_DIR" "$SRC_TOP"

# Stage PKGBUILD with version pinned.
cp "$SCRIPT_DIR/arch/PKGBUILD" "$WORK_DIR/PKGBUILD"
cp "$SCRIPT_DIR/arch/cde-plasma.install" "$WORK_DIR/cde-plasma.install"
sed -i "s/^pkgver=.*/pkgver=$VERSION/" "$WORK_DIR/PKGBUILD"

# Replace the GitHub URL with a relative file source so makepkg uses our
# local tarball rather than fetching from a tag that may not exist yet.
sed -i "s|source=.*|source=(\"cde-plasma-$VERSION.tar.gz\")|" "$WORK_DIR/PKGBUILD"

# makepkg refuses to run as root; CI containers run as root by default. We
# fall back to a throwaway 'builder' user when needed.
if [ "$(id -u)" -eq 0 ]; then
    if ! id builder &>/dev/null; then
        useradd -m -s /bin/bash builder
    fi
    chown -R builder:builder "$WORK_DIR"
    sudo -u builder bash -c "cd '$WORK_DIR' && makepkg -s --noconfirm --skipinteg"
else
    cd "$WORK_DIR" && makepkg -s --noconfirm --skipinteg
fi

# Copy outputs.
mv "$WORK_DIR"/*.pkg.tar.zst "$DIST_DIR/"
echo
echo "=== Built ==="
ls -lh "$DIST_DIR"/cde-plasma-*.pkg.tar.zst
