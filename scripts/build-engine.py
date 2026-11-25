#!/usr/bin/env python3
"""Builds the CLI against any official AngelScript release and installs it as angelscript-<version>.

  python scripts/build-engine.py 2.36.1
  python scripts/build-engine.py 2.30.2 --prefix ~/.local
  python scripts/build-engine.py --list

The release is downloaded from angelcode.com, checked against the SHA-256 pinned in angelscript-engine
(external/angelscript-engine, or ANGELSCRIPT_ENGINE_DIR) and patched there. The result is copied to
<prefix>/bin/angelscript-<version>; the default angelscript command is left alone.
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("version", nargs="?", help="official release, for example 2.36.1")
    parser.add_argument("--list", action="store_true", help="print the official releases and exit")
    parser.add_argument("--prefix", default=str(Path.home() / ".local"))
    parser.add_argument("--work", default=str(ROOT / "build" / "engine"))
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    parser.add_argument(
        "--engine-dir",
        default=os.environ.get("ANGELSCRIPT_ENGINE_DIR", str(ROOT / "external" / "angelscript-engine")),
        help="checkout of angelscript-engine",
    )
    parser.add_argument("--pin", action="store_true", help="accept a release that has no SHA-256 pin yet")
    args = parser.parse_args()

    engine_dir = Path(args.engine_dir).resolve()
    if not (engine_dir / "scripts" / "sdk.py").exists():
        sys.exit(f"angelscript-engine not found at {engine_dir}. Run: git submodule update --init external/angelscript-engine")
    sys.path.insert(0, str(engine_dir / "scripts"))
    import sdk

    if args.list:
        print("\n".join(sdk.official_versions()))
        return 0
    if not args.version:
        parser.error("pass a version or --list")
    if not shutil.which("cmake"):
        sys.exit("cmake is required")

    work = Path(args.work).resolve()
    cache = work / "cache"
    pins_path = engine_dir / "engines" / "versions.json"
    pins = sdk.load(pins_path, {})
    archive, _ = sdk.download(args.version, cache, pins, args.pin)
    root = sdk.extract(archive, work / "sdk" / args.version)
    for change in sdk.apply_sdk_fixes(root, args.version, cache, pins, args.pin):
        print(f"compatibility fix in the extracted copy: {change}")

    build = work / "build" / args.version
    log = work / "logs" / f"{args.version}.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    log.unlink(missing_ok=True)
    if build.exists():
        shutil.rmtree(build)
    configure = [
        "cmake",
        "-S",
        str(ROOT),
        "-B",
        str(build),
        "-DCMAKE_BUILD_TYPE=Release",
        f"-DANGELSCRIPT_SDK={root}",
        f"-DANGELSCRIPT_ENGINE_DIR={engine_dir}",
    ]
    if os.environ.get("ASDEBUGGER_DIR"):
        configure.append(f"-DASDEBUGGER_DIR={os.environ['ASDEBUGGER_DIR']}")
    if shutil.which("ninja"):
        configure += ["-G", "Ninja"]
    if sdk.run(configure, ROOT, log) != 0 or sdk.run(
        ["cmake", "--build", str(build), "--config", "Release", "--parallel", str(args.jobs)], ROOT, log
    ) != 0:
        text = log.read_text(encoding="utf-8", errors="replace")
        print(f"The build failed: {sdk.first_error(log)}")
        print("\n".join(text.splitlines()[-40:]))
        print(f"Full log: {log}")
        return 1

    suffix = ".exe" if platform.system() == "Windows" else ""
    binary = next((p for p in build.rglob(f"angelscript{suffix}") if p.is_file() and p.parent.name in ("bin", "Release")), None)
    if binary is None:
        sys.exit("The build produced no angelscript executable")
    destination = Path(args.prefix) / "bin" / f"angelscript-{args.version}{suffix}"
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(binary, destination)
    print(f"Installed {destination}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
