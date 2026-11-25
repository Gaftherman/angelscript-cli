#!/bin/sh
# Builds a native package from a built binary and adds its checksum to dist/SHA256SUMS.
#
#   sh scripts/package-os.sh deb <binary> <version> <x64|arm64>
#   sh scripts/package-os.sh pkg <binary> <version> <x64|arm64>
set -eu

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

[ "$#" -eq 4 ] || fail 'Usage: sh scripts/package-os.sh <deb|pkg> <binary> <version> <x64|arm64>'
kind=$1
binary=$2
version=$3
arch=$4

case $version in
    *[!0-9.]* | '' | .* | *. | *..*) fail 'The version must be x.y.z.' ;;
esac
case $arch in
    x64 | arm64) ;;
    *) fail 'The architecture must be x64 or arm64.' ;;
esac
[ -f "$binary" ] || fail "Missing binary: $binary"

root=$(CDPATH='' cd -P "$(dirname "$0")/.." && pwd -P)
dist=$root/dist
mkdir -p "$dist"
work=$(mktemp -d)
trap 'rm -rf "$work"' 0
trap 'exit 1' HUP INT TERM

if [ "$kind" = deb ]; then
    case $arch in
        x64) deb_arch=amd64 ;;
        arm64) deb_arch=arm64 ;;
    esac
    asset=angelscript-cli-$version-linux-$arch.deb
    pkg=$work/pkg
    mkdir -p "$pkg/DEBIAN" "$pkg/usr/bin" "$pkg/usr/share/doc/angelscript-cli"
    install -m 0755 "$binary" "$pkg/usr/bin/angelscript"
    ln -s angelscript "$pkg/usr/bin/asc"
    ln -s angelscript "$pkg/usr/bin/angelscript-cli"
    install -m 0644 "$root/LICENSE" "$pkg/usr/share/doc/angelscript-cli/copyright"
    install -m 0644 "$root/docs/THIRD_PARTY_NOTICES.md" "$pkg/usr/share/doc/angelscript-cli/THIRD_PARTY_NOTICES.md"
    size=$(du -sk "$pkg/usr" | cut -f1)
    cat >"$pkg/DEBIAN/control" <<EOF
Package: angelscript-cli
Version: $version
Section: devel
Priority: optional
Architecture: $deb_arch
Maintainer: Gaftherman <noreply@users.noreply.github.com>
Installed-Size: $size
Depends: libc6, libstdc++6
Homepage: https://github.com/Gaftherman/angelscript-cli
Description: Run AngelScript files from the terminal
 The angelscript command, also available as asc and angelscript-cli, runs
 AngelScript scripts with files, sockets, strings and dates, and debugs them
 from VS Code.
EOF
    dpkg-deb --root-owner-group --build "$pkg" "$work/$asset" >/dev/null
elif [ "$kind" = pkg ]; then
    asset=angelscript-cli-$version-macos-$arch.pkg
    payload=$work/root
    mkdir -p "$payload/usr/local/bin"
    install -m 0755 "$binary" "$payload/usr/local/bin/angelscript"
    ln -s angelscript "$payload/usr/local/bin/asc"
    ln -s angelscript "$payload/usr/local/bin/angelscript-cli"
    pkgbuild --root "$payload" --identifier io.github.gaftherman.angelscript-cli --version "$version" \
        --install-location / "$work/component.pkg" >/dev/null
    productbuild --package "$work/component.pkg" "$work/$asset" >/dev/null
else
    fail 'The first argument must be deb or pkg.'
fi

mv "$work/$asset" "$dist/$asset"
if command -v sha256sum >/dev/null 2>&1; then
    hash=$(sha256sum "$dist/$asset" | cut -d' ' -f1)
else
    hash=$(shasum -a 256 "$dist/$asset" | cut -d' ' -f1)
fi
manifest=$dist/SHA256SUMS
{
    if [ -f "$manifest" ]; then
        grep -v "  $asset\$" "$manifest" || true
    fi
    printf '%s  %s\n' "$hash" "$asset"
} | LC_ALL=C sort >"$work/sums"
mv "$work/sums" "$manifest"
printf 'Created %s\n' "$dist/$asset"
