#!/bin/bash
# Sets cone-player-bin's PKGBUILD to a Linux release (.github/workflows/aur-cone-player-bin.yml,
# redesign/SUBMIT_TO_AUR.md):
#   update-pkgbuild.sh <tag, e.g. linux-v1.2.0-beta3> <the release's tarball> [PKGBUILD]
# The tag's version becomes pkgver without its dash (1.2.0-beta3 -> 1.2.0beta3: pacman sorts
# 1.2.0beta3 before 1.2.0, so the final release upgrades the beta), pkgrel goes back to 1 and the
# sha256 is the tarball's.
set -euo pipefail

TAG=${1:?usage: $0 <linux-vX.Y.Z[-label]> <tarball> [PKGBUILD]}
TARBALL=${2:?usage: $0 <linux-vX.Y.Z[-label]> <tarball> [PKGBUILD]}
PKGBUILD=${3:-$(dirname "$0")/cone-player-bin/PKGBUILD}

case "$TAG" in
    linux-v[0-9]*.[0-9]*.[0-9]*) ;;
    *) echo "not a Linux release tag: $TAG" >&2; exit 1 ;;
esac
FILEVER=${TAG#linux-v}
if ! echo "$FILEVER" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$'; then
    echo "unexpected version in $TAG" >&2; exit 1
fi
PKGVER=${FILEVER//-/}
case "$(basename "$TARBALL")" in
    "Cone-$FILEVER-linux-x86_64.tar.xz") ;;
    *) echo "$TARBALL is not Cone-$FILEVER-linux-x86_64.tar.xz" >&2; exit 1 ;;
esac
SHA=$(sha256sum "$TARBALL" | cut -d' ' -f1)

for field in _tag _filever pkgver pkgrel sha256sums; do
    [ "$(grep -c "^$field=" "$PKGBUILD")" = 1 ] || { echo "$PKGBUILD: no single $field= line" >&2; exit 1; }
done
sed -i -e "s/^_tag=.*/_tag=$TAG/" \
       -e "s/^_filever=.*/_filever=$FILEVER/" \
       -e "s/^pkgver=.*/pkgver=$PKGVER/" \
       -e "s/^pkgrel=.*/pkgrel=1/" \
       -e "s/^sha256sums=.*/sha256sums=('$SHA')/" "$PKGBUILD"
echo "PKGBUILD: $TAG, pkgver $PKGVER, sha256 $SHA"
