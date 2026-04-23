#!/bin/bash
#
# build-debian.sh VERSION [--plasma5] — build cde-plasma .deb for
# Debian/Ubuntu.
#
# Default recipe (packaging/debian/) targets Plasma 6 / KF6 / Qt6 on
# Debian 13 (Trixie) and Ubuntu 24.10+.
# Pass --plasma5 to use the packaging/debian-plasma5/ recipe, which targets
# Plasma 5 / KF5 / Qt5 on Debian 12 (Bookworm) and Ubuntu 22.04 / 24.04.
#
# Runnable locally:
#   bash cde-plasma/packaging/build-debian.sh 0.1.0
#   bash cde-plasma/packaging/build-debian.sh 0.1.0 --plasma5

set -euo pipefail

VERSION="${1:-0.0.0}"
shift 2>/dev/null || true

RECIPE="debian"
for arg in "$@"; do
    case "$arg" in
        --plasma5) RECIPE="debian-plasma5" ;;
        --plasma6) RECIPE="debian" ;;
        *) echo "Unknown arg: $arg" >&2; exit 2 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
WORK_DIR="$(mktemp -d -t cde-debian-build-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$DIST_DIR"

echo "=== Debian/Ubuntu build: cde-plasma $VERSION (recipe: $RECIPE) ==="

# 3.0 (quilt) needs a separate orig.tar.gz alongside a source dir whose name
# matches <pkg>-<version>. Stage both.
SRC_TOP="cde-plasma-$VERSION"
mkdir -p "$WORK_DIR/$SRC_TOP"
rsync -a \
    --exclude='.git' \
    --exclude='build' \
    --exclude='build-*/' \
    --exclude='dist' \
    --exclude='prebuilt/*.tar.gz' \
    --exclude='debian' \
    "$REPO_ROOT/" "$WORK_DIR/$SRC_TOP/"

# Pristine orig tarball captured BEFORE we drop debian/ in.
( cd "$WORK_DIR" && tar czf "cde-plasma_$VERSION.orig.tar.gz" "$SRC_TOP" )

# Now place the selected debian/ recipe at the top of the source tree.
# dpkg-buildpackage always looks for a dir literally named "debian".
cp -r "$SCRIPT_DIR/$RECIPE" "$WORK_DIR/$SRC_TOP/debian"

# Patch changelog version + date so dpkg-buildpackage stops complaining about
# the placeholder. Use dch if available (preserves formatting), else sed.
if command -v dch &>/dev/null; then
    ( cd "$WORK_DIR/$SRC_TOP" && \
        EDITOR=true DEBEMAIL="cmcrann@protonmail.com" DEBFULLNAME="Connor McRann" \
        dch -v "${VERSION}-1" -D "stable" "Release ${VERSION}." )
else
    DATE_RFC="$(date -R)"
    sed -i \
        -e "s|^cde-plasma (0\\.0\\.0-1)|cde-plasma (${VERSION}-1)|" \
        -e "s|^cde-plasma (0\\.1\\.0)|cde-plasma (${VERSION})|" \
        -e "s|UNRELEASED;|stable;|" \
        -e "s|, 22 Apr 2026 14:00:00 +0000|${DATE_RFC#*, }|" \
        "$WORK_DIR/$SRC_TOP/debian/changelog" \
        "$WORK_DIR/$SRC_TOP/debian/cde-plasma.NEWS" 2>/dev/null || true
fi

cd "$WORK_DIR/$SRC_TOP"
dpkg-buildpackage -b -us -uc -d

# .deb / .changes / .buildinfo land in the parent dir.
mv "$WORK_DIR"/*.deb "$DIST_DIR/" 2>/dev/null || true
mv "$WORK_DIR"/*.buildinfo "$DIST_DIR/" 2>/dev/null || true
mv "$WORK_DIR"/*.changes "$DIST_DIR/" 2>/dev/null || true

echo
echo "=== Built ==="
ls -lh "$DIST_DIR"/cde-plasma_*.deb
