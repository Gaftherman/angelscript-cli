#!/usr/bin/env python3
"""Builds the CLI against an official AngelScript release and installs it as angelscript-<version>.
  python scripts/build-engine.py 2.36.1
  python scripts/build-engine.py 2.39.0 --jit
  python scripts/build-engine.py 2.30.2 --prefix ~/.local
  python scripts/build-engine.py --list
The bundled release (the current one) builds as it is. Any other release is downloaded from angelcode.com, checked
against the SHA-256 pinned in angelscript-engine (external/angelscript-engine, or ANGELSCRIPT_ENGINE_DIR) and patched
there. --jit adds the angelscript-jit compiler (AngelScript 2.33 and later, 64-bit x86 or arm64).
The result is copied to <prefix>/bin/angelscript-<version>[-jit], next to a .json file that says what the build
supports; the default angelscript command is left alone.
"""
import argparse
import os
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
BUNDLED_SDK = ROOT / "external" / "angelscript" / "sdk"
def bundled_version():
    header = BUNDLED_SDK / "angelscript" / "include" / "angelscript.h"
    if not header.exists():
        return None
    match = re.search(r'^#define ANGELSCRIPT_VERSION_STRING\s+"([^"]+)"', header.read_text(encoding="utf-8"), re.M)
    return match.group(1) if match else None
def load_engine(engine_dir):
    if not (engine_dir / "scripts" / "sdk.py").exists():
        sys.exit(f"angelscript-engine not found at {engine_dir}. Run: git submodule update --init external/angelscript-engine")
    sys.path.insert(0, str(engine_dir / "scripts"))
    import sdk
    return sdk
def run(command, log):
    with open(log, "a", encoding="utf-8") as stream:
        return subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT).returncode
def last_error(log):
    for line in reversed(log.read_text(encoding="utf-8", errors="replace").splitlines()):
        if "error" in line.lower():
            return line.strip()
    return "see the log"
def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("version", nargs="?", help="official release, for example 2.36.1 (default: the bundled one)")
    parser.add_argument("--list", action="store_true", help="print the official releases and exit")
    parser.add_argument("--jit", action="store_true", help="build with the angelscript-jit compiler")
    parser.add_argument("--prefix", default=str(Path.home() / ".local"))
    parser.add_argument("--work", default=str(ROOT / "build" / "engine"))
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    parser.add_argument(
        "--engine-dir",
        default=os.environ.get("ANGELSCRIPT_ENGINE_DIR", str(ROOT / "external" / "angelscript-engine")),
        help="checkout of angelscript-engine",
    )
    parser.add_argument(
        "--jit-dir",
        default=os.environ.get("ANGELSCRIPT_JIT_DIR", str(ROOT / "external" / "angelscript-jit")),
        help="checkout of angelscript-jit",
    )
    parser.add_argument("--pin", action="store_true", help="accept a release that has no SHA-256 pin yet")
    args = parser.parse_args()
    engine_dir = Path(args.engine_dir).resolve()
    if args.list:
        print("\n".join(load_engine(engine_dir).official_versions()))
        return 0
    bundled = bundled_version()
    version = args.version or bundled
    if not version:
        parser.error("pass a version or --list")
    if not shutil.which("cmake"):
        sys.exit("cmake is required")
    if args.jit and tuple(int(part) for part in re.findall(r"\d+", version)[:3]) < (2, 33, 0):
        sys.exit(f"--jit needs AngelScript 2.33.0 or later; {version} is older")
    work = Path(args.work).resolve()
    if version == bundled:
        root = BUNDLED_SDK
        print(f"AngelScript {version} is the bundled release: building it without patches")
    else:
        sdk = load_engine(engine_dir)
        cache = work / "cache"
        pins = sdk.load(engine_dir / "engines" / "versions.json", {})
        archive, _ = sdk.download(version, cache, pins, args.pin)
        root = sdk.extract(archive, work / "sdk" / version)
        for change in sdk.apply_sdk_fixes(root, version, cache, pins, args.pin):
            print(f"compatibility fix in the extracted copy: {change}")
    name = f"{version}-jit" if args.jit else version
    build = work / "build" / name
    log = work / "logs" / f"{name}.log"
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
    if args.jit:
        configure += ["-DANGELSCRIPT_CLI_JIT=angelsea", f"-DANGELSCRIPT_JIT_DIR={Path(args.jit_dir).resolve()}"]
    if os.environ.get("ASDEBUGGER_DIR"):
        configure.append(f"-DASDEBUGGER_DIR={os.environ['ASDEBUGGER_DIR']}")
    if shutil.which("ninja"):
        configure += ["-G", "Ninja"]
    if run(configure, log) != 0 or run(
        ["cmake", "--build", str(build), "--config", "Release", "--parallel", str(args.jobs)], log
    ) != 0:
        text = log.read_text(encoding="utf-8", errors="replace")
        print(f"The build failed: {last_error(log)}")
        print("\n".join(text.splitlines()[-40:]))
        print(f"Full log: {log}")
        return 1
    suffix = ".exe" if platform.system() == "Windows" else ""
    binary = next((p for p in build.rglob(f"angelscript{suffix}") if p.is_file() and p.parent.name in ("bin", "Release")), None)
    if binary is None:
        sys.exit("The build produced no angelscript executable")
    destination = Path(args.prefix) / "bin" / f"angelscript-{name}{suffix}"
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(binary, destination)
    info = build / "engine-info.json"
    if info.exists():
        shutil.copy2(info, destination.parent / f"angelscript-{name}.json")
    print(f"Installed {destination}")
    return 0
if __name__ == "__main__":
    sys.exit(main())
