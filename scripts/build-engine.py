#!/usr/bin/env python3
"""Builds the CLI against an official AngelScript release and installs it next to the default one.

  python scripts/build-engine.py 2.35.1 --prefix ~/.local
  python scripts/build-engine.py --list

The release is downloaded from angelcode.com and checked against engines/versions.json. The result
is installed as <prefix>/bin/angelscript-<version> (angelscript-<version>.exe on Windows) and keeps
the default `angelscript` command untouched. Needs CMake, Ninja or another generator, a C++20
compiler and a checkout with the submodules.
"""
import argparse
import importlib.util
import os
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("engine_matrix", HERE / "engine-matrix.py")
matrix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(matrix)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("version", nargs="?")
    parser.add_argument("--list", action="store_true", help="print the official versions and exit")
    parser.add_argument("--prefix", default=str(Path.home() / ".local"))
    parser.add_argument("--work", default=str(matrix.ROOT / "build" / "engine"))
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    args = parser.parse_args()
    if args.list:
        print("\n".join(matrix.official_versions()))
        return 0
    if not args.version:
        parser.error("a version is required")
    for tool in ("cmake",):
        if not shutil.which(tool):
            print(f"{tool} is required to build the engine from source.", file=sys.stderr)
            return 1
    work = Path(args.work)
    cache = work / "cache"
    pins_path = matrix.ENGINES / "versions.json"
    pins = matrix.load(pins_path, {})
    archive, digest = matrix.download(args.version, cache, pins)
    if args.version not in matrix.load(pins_path, {}):
        print(f"warning: no pinned SHA-256 for {args.version}; recorded {digest}", file=sys.stderr)
        matrix.save(pins_path, pins)
    sdk = matrix.extract(archive, work / "sdk" / args.version)
    for change in matrix.apply_sdk_fixes(sdk):
        print(f"compatibility fix in the extracted copy: {change}")
    build = work / "build" / args.version
    log = work / "logs" / f"{args.version}.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    log.unlink(missing_ok=True)
    configure = ["cmake", "-S", str(matrix.ROOT), "-B", str(build), "-DCMAKE_BUILD_TYPE=Release",
                 f"-DANGELSCRIPT_SDK={sdk}"]
    if shutil.which("ninja"):
        configure += ["-G", "Ninja"]
    if matrix.run(configure, matrix.ROOT, log) != 0 or \
       matrix.run(["cmake", "--build", str(build), "--config", "Release", "--parallel", str(args.jobs)],
                  matrix.ROOT, log) != 0:
        print(f"The build failed: {matrix.first_error(log) or log}", file=sys.stderr)
        return 1
    suffix = ".exe" if os.name == "nt" else ""
    binary = next((p for p in build.rglob(f"angelscript{suffix}") if p.is_file() and p.parent.name != "CMakeFiles"), None)
    if not binary:
        print("The build did not produce an angelscript executable.", file=sys.stderr)
        return 1
    bin_dir = Path(args.prefix) / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    target = bin_dir / f"angelscript-{args.version}{suffix}"
    shutil.copy2(binary, target)
    print(f"Installed {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
