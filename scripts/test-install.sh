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
TEST_ARCHIVE=$archive TEST_CHECKSUMS=$checksums TEST_ASSET=$asset PATH="$work/tools:$PATH" \
    "$test_shell" -s -- --prefix "$prefix" < "$installer"
assert_version

for _ in 1 2; do
    "$test_shell" "$installer" --prefix "$prefix" --uninstall
    assert_uninstalled
done
# An engine build installs next to the default one and only adds angelscript-<engine>.
engine_asset=angelscript-cli-$expected_version-as2.39.0-${asset#angelscript-cli-$expected_version-}
cp "$archive" "$work/$engine_asset"
printf '%s  %s\n' "$(sha256sum < "$archive" | cut -d' ' -f1)" "$engine_asset" > "$work/engine-sums"
"$test_shell" "$installer" --prefix "$prefix" --engine 2.39.0 --archive "$work/$engine_asset" --checksums "$work/engine-sums" --no-modify-path
[ -x "$prefix/bin/angelscript-2.39.0" ] || fail 'The engine build was not linked.'
[ ! -e "$prefix/bin/angelscript" ] || fail 'The engine build must not take over the default command.'
"$prefix/bin/angelscript-2.39.0" --version | grep -q 'AngelScript 2.39.0' || fail 'The engine build reports another release.'
if "$test_shell" "$installer" --prefix "$prefix" --engine 2.99.0 --version 9.9.9 --no-modify-path >/dev/null 2>&1; then
    fail 'A missing prebuilt engine must fail.'
fi
"$test_shell" "$installer" --prefix "$prefix" --engine 2.39.0 --uninstall --no-modify-path
[ ! -e "$prefix/bin/angelscript-2.39.0" ] || fail 'The engine link remained after uninstall.'
printf '%s\n' 'Offline POSIX installer test passed.'
