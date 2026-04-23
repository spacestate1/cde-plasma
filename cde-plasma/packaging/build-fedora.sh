#!/bin/bash
#
# build-fedora.sh VERSION — build cde-plasma .rpm for Fedora.
#
# Used by CI on fedora:40+. Runnable locally:
#   bash cde-plasma/packaging/build-fedora.sh 0.1.0

set -euo pipefail

VERSION="${1:-0.0.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
RPM_TOP="$(mktemp -d -t cde-fedora-build-XXXXXX)"
trap 'rm -rf "$RPM_TOP"' EXIT

mkdir -p "$DIST_DIR"
mkdir -p "$RPM_TOP"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

echo "=== Fedora build: cde-plasma $VERSION ==="

# Source tarball — top dir cde-plasma-VERSION/ matches %autosetup default.
SRC_TOP="cde-plasma-$VERSION"
STAGE="$(mktemp -d)"
mkdir -p "$STAGE/$SRC_TOP"
rsync -a \
    --exclude='.git' \
    --exclude='build' \
    --exclude='build-*/' \
    --exclude='dist' \
    --exclude='prebuilt/*.tar.gz' \
    "$REPO_ROOT/" "$STAGE/$SRC_TOP/"
tar czf "$RPM_TOP/SOURCES/v$VERSION.tar.gz" -C "$STAGE" "$SRC_TOP"
rm -rf "$STAGE"

# Spec with version pinned.
cp "$SCRIPT_DIR/fedora/cde-plasma.spec" "$RPM_TOP/SPECS/cde-plasma.spec"
sed -i "s/^Version:.*$/Version:        $VERSION/" "$RPM_TOP/SPECS/cde-plasma.spec"

rpmbuild --define "_topdir $RPM_TOP" -ba "$RPM_TOP/SPECS/cde-plasma.spec"

# Move binary RPMs (skip src.rpm, we don't ship those for now).
find "$RPM_TOP/RPMS" -name '*.rpm' -exec mv {} "$DIST_DIR/" \;

echo
echo "=== Built ==="
ls -lh "$DIST_DIR"/cde-plasma-*.rpm
