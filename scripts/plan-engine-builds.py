#!/usr/bin/env python3
"""Prints the build matrix of .github/workflows/engine-builds.yml as JSON: {"include": [...]}.

One entry per AngelScript release and target, plus a JIT entry for the releases and targets that can have one. The
list of releases lives here so the workflow, the installer and the documentation agree on it.
  python scripts/plan-engine-builds.py            # the whole matrix
  python scripts/plan-engine-builds.py --releases # only the releases, newest first
"""
import argparse
import json

# Newest first. The first one is the bundled release (external/angelscript); the others are patched by angelscript-engine.
RELEASES = ["2.39.0", "2.38.0", "2.37.0", "2.36.1", "2.35.1", "2.33.0", "2.30.2"]
# The JIT runs through asIJITCompilerV2 from 2.37 and through the version 1 interface (asIJITCompiler) from 2.33.
JIT_FROM = (2, 33, 0)
TARGETS = [
    {"runner": "windows-latest", "os": "windows", "arch": "x64", "msvc": "x64", "toolchain": "", "jit": True},
    {"runner": "windows-latest", "os": "windows", "arch": "x86", "msvc": "amd64_x86", "toolchain": "", "jit": False},
    {"runner": "ubuntu-24.04", "os": "linux", "arch": "x64", "msvc": "x64", "toolchain": "", "jit": True},
    {"runner": "ubuntu-24.04", "os": "linux", "arch": "x86", "msvc": "x64", "toolchain": "cmake/linux-x86.cmake", "jit": False},
    {"runner": "ubuntu-24.04-arm", "os": "linux", "arch": "arm64", "msvc": "x64", "toolchain": "", "jit": True},
    {"runner": "macos-15", "os": "macos", "arch": "arm64", "msvc": "x64", "toolchain": "", "jit": True},
    {"runner": "macos-15-intel", "os": "macos", "arch": "x64", "msvc": "x64", "toolchain": "", "jit": False},
]


def version_tuple(version):
    return tuple(int(part) for part in version.split("."))


def plan():
    entries = []
    for release in RELEASES:
        for target in TARGETS:
            base = {key: value for key, value in target.items() if key != "jit"}
            entries.append({**base, "engine": release, "jit": False, "name": release})
            if target["jit"] and version_tuple(release) >= JIT_FROM:
                entries.append({**base, "engine": release, "jit": True, "name": f"{release}-jit"})
    return {"include": entries}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--releases", action="store_true", help="print only the releases")
    args = parser.parse_args()
    print(json.dumps(RELEASES if args.releases else plan(), separators=(",", ":")))


if __name__ == "__main__":
    main()
