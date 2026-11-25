#!/bin/sh
# Installs a .deb or .pkg built by package-os.sh, checks the three commands, and removes it.
# Needs root (or sudo) because both formats install system-wide.
#
#   sh scripts/test-os-package.sh dist/angelscript-cli-1.1.0-linux-x64.deb 1.1.0
set -eu

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

[ "$#" -eq 2 ] || fail 'Usage: sh scripts/test-os-package.sh <package> <version>'
package=$1
version=$2
[ -f "$package" ] || fail "Missing package: $package"

if [ "$(id -u)" -eq 0 ]; then
    as_root=
else
    as_root=sudo
fi

case $package in
    *.deb)
        bin=/usr/bin
        $as_root dpkg -i "$package"
        ;;
    *.pkg)
        bin=/usr/local/bin
        $as_root installer -pkg "$package" -target /
        ;;
    *) fail 'Pass a .deb or .pkg file.' ;;
esac

status=0
for name in angelscript asc angelscript-cli; do
    [ -L "$bin/$name" ] || [ -x "$bin/$name" ] || { printf 'Missing %s/%s\n' "$bin" "$name" >&2; status=1; continue; }
    output=$("$bin/$name" --version) || { printf '%s failed\n' "$name" >&2; status=1; continue; }
    case $output in
        "angelscript $version "*) ;;
        *) printf 'Unexpected --version from %s: %s\n' "$name" "$output" >&2; status=1 ;;
    esac
done

case $package in
    *.deb) $as_root dpkg -r angelscript-cli ;;
    *.pkg) $as_root rm -f "$bin/angelscript" "$bin/asc" "$bin/angelscript-cli" ;;
esac
for name in angelscript asc angelscript-cli; do
    if [ -e "$bin/$name" ] || [ -L "$bin/$name" ]; then
        printf '%s/%s was left behind\n' "$bin" "$name" >&2
        status=1
    fi
done
[ "$status" -eq 0 ] || exit 1
printf 'Package test passed for %s\n' "$package"
