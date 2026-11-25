#!/bin/sh
set -eu

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

version=latest
engine=${ANGELSCRIPT_ENGINE_VERSION-}
jit=${ANGELSCRIPT_CLI_JIT:+yes}
jit=${jit:-no}
archive=
checksums=
prefix=$HOME/.local
modify_path=yes
uninstall=no
while [ "$#" -gt 0 ]; do
    case $1 in
        --version|--engine|--archive|--checksums|--prefix)
            if [ "$#" -lt 2 ] || [ -z "$2" ]; then fail "$1 requires a value"; fi
            case $1 in
                --version) version=$2 ;;
                --engine) engine=$2 ;;
                --archive) archive=$2 ;;
                --checksums) checksums=$2 ;;
                --prefix) prefix=$2 ;;
            esac
            shift ;;
        --jit) jit=yes ;;
        --no-modify-path) modify_path=no ;;
        --uninstall) uninstall=yes ;;
        *) fail "Unknown option: $1" ;;
    esac
    shift
done

case $prefix in
    /*) ;;
    *) prefix=$(pwd -P)/$prefix ;;
esac
case $prefix in
    *:*|*'
'*) fail 'The prefix cannot contain a colon or newline.' ;;
esac
if [ "$uninstall" = no ]; then
    mkdir -p "$prefix"
fi
if [ -d "$prefix" ]; then prefix=$(CDPATH='' cd -P "$prefix" && pwd -P); fi
share=${prefix%/}/share
bin=${prefix%/}/bin
# One AngelScript release is installed at a time, like Python: --engine and --jit choose which build replaces the
# installed one (same folder, same commands).
case $engine in
    '') ;;
    *[!0-9.]*) fail 'The engine must be an AngelScript version such as 2.35.1.' ;;
    *) printf '%s\n' "$engine" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || fail 'The engine must be an AngelScript version such as 2.35.1.' ;;
esac
install_dir=$share/angelscript-cli
command_names="angelscript asc angelscript-cli"
program=$install_dir/angelscript

# Quote the literal directory for use in both a shell pattern and an assignment.
quoted_bin=$(printf '%s\n' "$bin" | sed "s/'/'\\\\''/g")
path_line="case \":\${PATH-}:\" in *':$quoted_bin:'*|*':$quoted_bin/:'*) ;; *) export PATH='$quoted_bin'\${PATH:+\":\$PATH\"} ;; esac # angelscript-cli"
login_shell=${SHELL-}
case ${BASH_VERSION:+bash}${ZSH_VERSION:+zsh} in
    bash) rc=$HOME/.bashrc ;;
    zsh) rc=$HOME/.zshrc ;;
    *)
        case ${login_shell##*/} in
            bash) rc=$HOME/.bashrc ;;
            zsh) rc=$HOME/.zshrc ;;
            *) rc= ;;
        esac ;;
esac

append_path() {
    if [ -f "$1" ] && grep -Fqx -e "$path_line" "$1"; then return; fi
    if [ -s "$1" ] && [ -n "$(tail -c 1 "$1")" ]; then printf '\n' >> "$1"; fi
    printf '%s\n' "$path_line" >> "$1"
}

remove_path() {
    [ -f "$1" ] && grep -Fqx -e "$path_line" "$1" || return 0
    PATH_LINE=$path_line awk '$0 != ENVIRON["PATH_LINE"]' "$1" > "$work/profile"
    cat "$work/profile" > "$1"
}

download() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$2" "$1"
    else
        fail 'Install curl or wget to download a release.'
    fi
}

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum < "$1"
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 < "$1"
    else
        fail 'Install sha256sum or shasum to verify the archive.'
    fi
}

# A command link is ours when it points inside the install directory (0.1 linked angelscript-cli).
is_owned_link() {
    [ -L "$1" ] || return 1
    case $(readlink "$1") in
        "$install_dir"/*) return 0 ;;
    esac
    return 1
}
if [ -L "$install_dir" ] || { [ -e "$install_dir" ] && [ ! -d "$install_dir" ]; }; then
    fail "The install path must be a regular directory: $install_dir"
fi
if [ -d "$install_dir" ]; then
    unexpected=$(find "$install_dir/." -name . -o -prune \
        ! \( -type f \( -name angelscript -o -name angelscript-cli -o -name LICENSE -o -name THIRD_PARTY_NOTICES.md -o -name README.md \) \) -print)
    [ -z "$unexpected" ] || fail "The install directory contains files owned by something else: $install_dir"
fi

if [ "$uninstall" = yes ]; then
    for name in $command_names; do
        if is_owned_link "$bin/$name"; then rm -f "$bin/$name"; fi
    done
    if [ -d "$install_dir" ]; then rm -rf "$install_dir"; fi
    if [ "$modify_path" = yes ]; then
        work=$(mktemp -d "$HOME/.angelscript-cli.XXXXXXXXXX")
        trap 'rm -rf "$work"' 0
        trap 'exit 1' HUP INT TERM
        remove_path "$HOME/.profile"
        remove_path "$HOME/.bashrc"
        remove_path "$HOME/.zshrc"
    fi
    printf '%s\n' 'Uninstalled angelscript.'
    exit 0
fi

case "$(uname -s)" in
    Linux) os=linux ;;
    Darwin) os=macos ;;
    *) fail 'This installer supports Linux and macOS.' ;;
esac
case "$(uname -m)" in
    x86_64) arch=x64 ;;
    i386|i486|i586|i686) arch=x86 ;;
    aarch64|arm64) arch=arm64 ;;
    *) fail 'This installer supports x64, x86 and arm64.' ;;
esac
case $version in
    latest) ;;
    *[!0-9.]*) fail 'Version must be x.y.z or latest.' ;;
    *) printf '%s\n' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || fail 'Version must be x.y.z or latest.' ;;
esac
for name in $command_names; do
    if ! is_owned_link "$bin/$name" && { [ -e "$bin/$name" ] || [ -L "$bin/$name" ]; }; then
        fail "The command path is already in use: $bin/$name"
    fi
done

mkdir -p "$share" "$bin"
work=$(mktemp -d "$share/.angelscript-cli.XXXXXXXXXX")
stage=$work/stage
backup=$work/previous
restore=no
cleanup() {
    if [ "$restore" = yes ] && [ -d "$backup" ]; then
        if [ -e "$install_dir" ] || ! mv "$backup" "$install_dir"; then
            printf 'The previous installation is at %s\n' "$backup" >&2
            return
        fi
    fi
    rm -rf "$work"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

if [ -z "$archive" ]; then
    base=https://github.com/Gaftherman/angelscript-cli/releases
    if [ "$version" = latest ]; then
        base=$base/latest/download
    else
        base=$base/download/v$version
    fi
    if [ -z "$checksums" ]; then
        checksums=$work/SHA256SUMS
        download "$base/SHA256SUMS" "$checksums"
    fi
    if [ "$version" = latest ]; then
        pattern="^angelscript-cli-[0-9]+[.][0-9]+[.][0-9]+-$os-${arch}[.]tar[.]gz$"
        asset=$(LC_ALL=C awk -v pattern="$pattern" '
            length($1) == 64 && $1 ~ /^[[:xdigit:]]+$/ && $2 ~ pattern && NF == 2 {
                name = $2
                count++
            }
            END { if (count == 1) print name; else exit 1 }
        ' "$checksums") || fail "Expected one $os $arch asset in the latest release SHA256SUMS."
    else
        asset=angelscript-cli-$version-$os-$arch.tar.gz
    fi
    if [ -n "$engine" ] || [ "$jit" = yes ]; then
        # Builds against a given release are listed as angelscript-cli-<cli>-as<engine>[-jit]-<os>-<arch>.tar.gz.
        # With --jit alone, the newest release that has a JIT build is used.
        if [ -n "$engine" ]; then engine_pattern=$(printf '%s' "$engine" | sed 's/[.]/[.]/g'); else engine_pattern='[0-9]+[.][0-9]+[.][0-9]+'; fi
        if [ "$jit" = yes ]; then jit_part=-jit; else jit_part=; fi
        pattern="^angelscript-cli-[0-9]+[.][0-9]+[.][0-9]+-as(${engine_pattern})${jit_part}-$os-${arch}[.]tar[.]gz\$"
        asset=$(LC_ALL=C awk -v pattern="$pattern" '
            length($1) == 64 && $1 ~ /^[[:xdigit:]]+$/ && NF == 2 && $2 ~ pattern {
                name = $2
                engine_version = $2
                sub(/^angelscript-cli-[0-9]+[.][0-9]+[.][0-9]+-as/, "", engine_version)
                sub(/(-jit)?-(linux|macos)-(x64|x86|arm64)[.]tar[.]gz$/, "", engine_version)
                split(engine_version, part, ".")
                rank = part[1] * 1000000 + part[2] * 1000 + part[3]
                if (rank >= best) { best = rank; best_name = name }
            }
            END { if (best_name != "") print best_name }
        ' "$checksums")
        if [ -z "$asset" ] || ! download "$base/$asset" "$work/$asset" 2>/dev/null; then
            wanted="AngelScript ${engine:-releases}"
            if [ "$jit" = yes ]; then
                fail "No prebuilt build of $wanted with the JIT for $os $arch in this release. Build it from source with: python scripts/build-engine.py <version> --jit (the JIT needs AngelScript 2.37 or later and a 64-bit system)."
            fi
            fail "No prebuilt build for AngelScript $engine. Build it from source with: python scripts/build-engine.py $engine"
        fi
    fi
    archive=$work/$asset
    [ -f "$archive" ] || download "$base/$asset" "$archive"
else
    asset=${archive##*/}
    if [ -z "$checksums" ]; then
        printf '%s\n' 'Local archive supplied without SHA256SUMS. Skipping checksum verification.'
    fi
fi
if [ -n "$checksums" ]; then
    expected=$(ASSET=$asset LC_ALL=C awk '
        length($0) > 66 && substr($0, 65, 2) == "  " && substr($0, 67) == ENVIRON["ASSET"] &&
            substr($0, 1, 64) ~ /^[[:xdigit:]]+$/ { hash = tolower(substr($0, 1, 64)); count++ }
        END { if (count == 1) print hash; else exit 1 }
    ' "$checksums") || fail "Expected one SHA-256 entry for $asset in SHA256SUMS."
    actual=$(sha256 "$archive")
    [ "$expected" = "${actual%% *}" ] || fail "SHA-256 mismatch for $asset."
fi

tar -tzf "$archive" > "$work/entries"
if [ "$(LC_ALL=C sort "$work/entries")" != "$(printf '%s\n' LICENSE README.md THIRD_PARTY_NOTICES.md angelscript)" ]; then
    fail "Unexpected files in $asset. Expected LICENSE, README.md, THIRD_PARTY_NOTICES.md and angelscript at the archive root."
fi
mkdir "$stage"
for entry in LICENSE README.md THIRD_PARTY_NOTICES.md angelscript; do
    tar -xOzf "$archive" "$entry" > "$stage/$entry"
done
chmod 755 "$stage/angelscript"
version_output=$("$stage/angelscript" --version)
case $version_output in
    'angelscript '[0-9]*.[0-9]*.[0-9]*) ;;
    *) fail 'The executable did not report a valid angelscript version.' ;;
esac

if [ -d "$install_dir" ]; then
    restore=yes
    mv "$install_dir" "$backup"
fi
mv "$stage" "$install_dir"
restore=no
for name in $command_names; do
    if is_owned_link "$bin/$name"; then rm -f "$bin/$name"; fi
    if ! ln -s "$program" "$bin/$name"; then
        rm -rf "$install_dir"
        restore=yes
        fail "Could not create $bin/$name."
    fi
done
if [ "$modify_path" = yes ]; then
    case ":${PATH-}:" in
        *":$bin:"*|*":$bin/:"*) ;;
        *)
            append_path "$HOME/.profile"
            if [ -n "$rc" ]; then append_path "$rc"; fi
            printf '%s\n' 'Open a new terminal to pick up the PATH change.' ;;
    esac
fi
"$bin/${command_names%% *}" --version
