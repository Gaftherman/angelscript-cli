#!/bin/sh
set -eu

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    fail 'Usage: sh scripts/test-install.sh <archive> <SHA256SUMS> [temp-root]'
fi
archive=$1
checksums=$2
asset=${archive##*/}
expected_version=$(printf '%s\n' "$asset" |
    sed -n 's/^angelscript-cli-\([0-9][0-9.]*\)-[a-z]*-[a-z0-9]*[.]tar[.]gz$/\1/p')
[ -n "$expected_version" ] || fail 'Pass a packaged Linux or macOS archive.'
installer=$(CDPATH='' cd -P "$(dirname "$0")" && pwd -P)/install.sh
temp_root=$(CDPATH='' cd -P "${3:-${TMPDIR:-/tmp}}" && pwd -P)
work=$(mktemp -d "$temp_root/angelscript-cli-test.XXXXXXXXXX")
trap 'rm -rf "$work"' 0
trap 'exit 1' HUP INT TERM

HOME=$work/home
SHELL=/bin/bash
export HOME SHELL
test_shell=${ANGELSCRIPT_CLI_TEST_SHELL:-sh}
case ${test_shell##*/} in
    zsh) rc=$HOME/.zshrc ;;
    *) rc=$HOME/.bashrc ;;
esac
mkdir "$HOME"
prefix="$work/custom prefix's"
link=$prefix/bin/angelscript
names='angelscript asc angelscript-cli'
install_dir=$prefix/share/angelscript-cli
printf '%s\n' '# original profile' > "$work/original-profile"
cp "$work/original-profile" "$HOME/.profile"
cp "$work/original-profile" "$rc"

assert_version() {
    [ -x "$install_dir/angelscript" ] || fail 'Missing executable.'
    for name in $names; do
        [ -L "$prefix/bin/$name" ] || fail "Missing symlink $name."
        output=$("$prefix/bin/$name" --version)
        case $output in
            "angelscript $expected_version "*|"angelscript $expected_version") ;;
            *) fail "Unexpected version from $name: $output" ;;
        esac
    done
}

assert_profiles_unchanged() {
    for profile in "$HOME/.profile" "$rc"; do
        cmp -s "$work/original-profile" "$profile" || fail "Changed PATH in $profile."
    done
}

assert_uninstalled() {
    if [ -e "$install_dir" ]; then fail 'Uninstall left the binary.'; fi
    for name in $names; do
        if [ -L "$prefix/bin/$name" ] || [ -e "$prefix/bin/$name" ]; then fail "Uninstall left $name."; fi
    done
    assert_profiles_unchanged
}

"$test_shell" "$installer" --archive "$archive" --prefix "$prefix" --no-modify-path
assert_version
assert_profiles_unchanged
"$test_shell" "$installer" --prefix "$prefix" --no-modify-path --uninstall
assert_uninstalled

PATH="$prefix/bin:$PATH" "$test_shell" "$installer" --archive "$archive" --checksums "$checksums" --prefix "$prefix"
assert_profiles_unchanged

for _ in 1 2; do
    "$test_shell" "$installer" --archive "$archive" --checksums "$checksums" --prefix "$prefix"
    assert_version
    for profile in "$HOME/.profile" "$rc"; do
        [ "$(grep -c '# angelscript-cli$' "$profile")" = 1 ] || fail "Expected one PATH entry in $profile."
    done
done
sh -c '
    . "$HOME/.profile"
    . "$3"
    [ "$PATH" = "$1/bin:$2" ] && command -v angelscript >/dev/null && command -v asc >/dev/null && command -v angelscript-cli >/dev/null
' sh "$prefix" "$PATH" "$rc" || fail 'The profile PATH guard did not work.'

printf '%064d  %s\n' 0 "$asset" > "$work/bad-checksums"
if "$test_shell" "$installer" --archive "$archive" --checksums "$work/bad-checksums" --prefix "$prefix" > "$work/bad-output" 2>&1; then
    fail 'Installer accepted an incorrect SHA-256.'
fi
grep -Fq 'SHA-256 mismatch' "$work/bad-output" || fail 'Installer failed for a reason other than the checksum.'
assert_version

"$test_shell" "$installer" --prefix "$prefix" --uninstall
assert_uninstalled

# Exercise the piped install with local copies of the two release downloads.
mkdir "$work/tools"
cat > "$work/tools/curl" <<'SH'
#!/bin/sh
set -eu
base=https://github.com/Gaftherman/angelscript-cli/releases/latest/download
case $2 in
    "$base/SHA256SUMS") cp "$TEST_CHECKSUMS" "$4" ;;
    "$base/$TEST_ASSET") cp "$TEST_ARCHIVE" "$4" ;;
    *) exit 1 ;;
esac
SH
chmod +x "$work/tools/curl"
# The archive under test can be for another architecture than the runner (a 32-bit build on an x64 host).
case $asset in
    *-x86.tar.gz) test_machine=i686 ;;
    *-arm64.tar.gz) test_machine=aarch64 ;;
    *) test_machine=x86_64 ;;
esac
cat > "$work/tools/uname" <<'SH'
#!/bin/sh
if [ "${1:-}" = -m ]; then printf '%s
' "$TEST_MACHINE"; else exec /usr/bin/uname "$@"; fi
SH
chmod +x "$work/tools/uname"
TEST_MACHINE=$test_machine TEST_ARCHIVE=$archive TEST_CHECKSUMS=$checksums TEST_ASSET=$asset PATH="$work/tools:$PATH" \
    "$test_shell" -s -- --prefix "$prefix" < "$installer"
assert_version

for _ in 1 2; do
    "$test_shell" "$installer" --prefix "$prefix" --uninstall
    assert_uninstalled
done
# One release is installed at a time: --engine and --jit pick which prebuilt build replaces the installed one. A fake
# curl serves a release that lists a plain build, two engine builds and two JIT builds, and logs what was requested.
suffix=${asset#angelscript-cli-$expected_version-}
# The archive under test can be for another architecture than the runner (a 32-bit build on an x64 host).
target_arch=${suffix#*-}
target_arch=${target_arch%.tar.gz}
serve=$work/serve
mkdir -p "$serve" "$work/fake"
: > "$serve/SHA256SUMS"
for build in "" as2.39.0- as2.38.0- as2.39.0-jit- as2.38.0-jit-; do
    name=angelscript-cli-$expected_version-$build$suffix
    cp "$archive" "$serve/$name"
    printf '%s  %s\n' "$(sha256sum < "$archive" | cut -d' ' -f1)" "$name" >> "$serve/SHA256SUMS"
done
cat > "$work/fake/curl" <<'SH'
#!/bin/sh
# usage: curl -fsSL <url> -o <file>
url=$2
out=$4
printf '%s\n' "${url##*/}" >> "$TEST_CURL_LOG"
[ -f "$TEST_SERVE/${url##*/}" ] || exit 22
cp "$TEST_SERVE/${url##*/}" "$out"
SH
chmod +x "$work/fake/curl"
install_with() {
    : > "$work/curl.log"
    TEST_SERVE=$serve TEST_CURL_LOG=$work/curl.log PATH="$work/fake:$PATH" \
        "$test_shell" "$installer" --prefix "$prefix" --version "$expected_version" --arch "$target_arch" --no-modify-path "$@" > "$work/install.out" 2>&1
}
picked() { grep -v '^SHA256SUMS$' "$work/curl.log" | tail -n 1; }
install_with --engine 2.38.0 || fail "--engine 2.38.0 failed: $(cat "$work/install.out")"
[ "$(picked)" = "angelscript-cli-$expected_version-as2.38.0-$suffix" ] || fail "--engine 2.38.0 picked $(picked)"
[ -x "$prefix/bin/angelscript" ] && [ -x "$prefix/bin/asc" ] || fail 'The chosen release must install the usual commands.'
[ ! -e "$prefix/bin/angelscript-2.38.0" ] || fail 'The chosen release must replace the installed one, not sit next to it.'
install_with --jit || fail "--jit failed: $(cat "$work/install.out")"
[ "$(picked)" = "angelscript-cli-$expected_version-as2.39.0-jit-$suffix" ] || fail "--jit alone must pick the newest JIT build, not $(picked)"
install_with --engine 2.38.0 --jit || fail "--engine 2.38.0 --jit failed: $(cat "$work/install.out")"
[ "$(picked)" = "angelscript-cli-$expected_version-as2.38.0-jit-$suffix" ] || fail "--engine 2.38.0 --jit picked $(picked)"
if install_with --engine 2.99.0; then fail 'A missing prebuilt engine must fail.'; fi
grep -q 'build-engine.py 2.99.0' "$work/install.out" || fail 'The error must say how to build the release from source.'
if install_with --engine 2.36.1 --jit; then fail 'A release without a JIT build must fail with --jit.'; fi
grep -q -- '--jit' "$work/install.out" || fail 'The error must mention how to build the JIT from source.'
"$test_shell" "$installer" --prefix "$prefix" --uninstall --no-modify-path
[ ! -e "$prefix/bin/angelscript" ] || fail 'The commands remained after uninstall.'
printf '%s\n' 'Offline POSIX installer test passed.'
