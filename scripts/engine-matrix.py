#!/usr/bin/env python3
"""Builds and tests the CLI against official AngelScript releases from angelcode.com.

  python scripts/engine-matrix.py --list
  python scripts/engine-matrix.py --versions 2.38.0,2.37.0 --work build/matrix
  python scripts/engine-matrix.py --from 2.20.0 --work build/matrix

Each run records, per version, whether the CLI builds, whether CTest passes and the first error in
engines/matrix.json. The SHA-256 of every downloaded archive is pinned in engines/versions.json the
first time it is seen and checked on every later download.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENGINES = ROOT / "engines"
BASE = "https://www.angelcode.com/angelscript"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}


def fetch(url, timeout=120):
    # angelcode.com rejects requests that do not look like a browser.
    request = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def version_key(version):
    return [int(part) if part.isdigit() else part for part in re.split(r"[.]|(?<=\d)(?=[a-z])", version)]


def official_versions():
    html = fetch(f"{BASE}/downloads.html").decode("utf-8", "replace")
    found = set(re.findall(r'/angelscript/sdk/files/angelscript_([0-9][0-9.]*[0-9a-z]?)\.zip', html))
    return sorted(found, key=version_key)


def load(path, default):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")


def download(version, cache, pins):
    archive = cache / f"angelscript_{version}.zip"
    if not archive.exists():
        cache.mkdir(parents=True, exist_ok=True)
        archive.write_bytes(fetch(f"{BASE}/sdk/files/angelscript_{version}.zip"))
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    pinned = pins.get(version)
    if pinned and pinned != digest:
        raise SystemExit(f"SHA-256 of angelscript_{version}.zip changed: pinned {pinned}, got {digest}")
    pins[version] = digest
    return archive, digest


def extract(archive, destination):
    if destination.exists():
        shutil.rmtree(destination)
    with zipfile.ZipFile(archive) as bundle:
        bundle.extractall(destination)
    for candidate in (destination / "sdk", *destination.glob("*/sdk")):
        if (candidate / "angelscript" / "include" / "angelscript.h").exists():
            return candidate
    # The oldest layouts have no sdk/ folder: find the include directory and take the folder above angelscript/.
    for header in destination.rglob("angelscript.h"):
        if header.parent.name == "include" and header.parent.parent.name == "angelscript":
            return header.parent.parent.parent
    raise RuntimeError("no sdk/angelscript/include/angelscript.h in the archive")


# Fixes applied to the extracted copy of a release, never to the repository or the download. Each one is a
# one-line change that a current compiler requires and that does not alter behaviour.
SDK_FIXES = [
    # scriptarray.cpp of 2.24 and 2.25 compares a function pointer with >= 0.
    ("add_on/scriptarray/scriptarray.cpp", "cache->cmpFunc >= 0", "cache->cmpFunc != 0"),
    # angelscript.h of 2.20 and 2.21 returns 0 where an asSFuncPtr is expected in a template that is never used.
    ("angelscript/include/angelscript.h", r"(ERROR_UnsupportedMethodPtr\[N-100\];\s*)return 0;", r"\1return asSFuncPtr();"),
    # as_compiler.cpp of 2.20.2 passes false where an object type pointer is expected.
    ("angelscript/source/as_compiler.cpp", "&funcPtr, node, true, true, false);", "&funcPtr, node, true, true, 0);"),
]


def apply_sdk_fixes(sdk):
    applied = []
    for relative, old, new in SDK_FIXES:
        path = sdk / relative
        if path.exists():
            text = path.read_text(encoding="utf-8", errors="surrogateescape")
            changed = re.sub(old, new, text) if old.startswith("(") else text.replace(old, new)
            if changed != text:
                path.write_text(changed, encoding="utf-8", errors="surrogateescape", newline="")
                applied.append(f"{relative}: {old} -> {new}")
    return applied


def run(command, cwd, log):
    with log.open("a", encoding="utf-8", errors="replace") as out:
        out.write("$ " + " ".join(map(str, command)) + "\n")
        out.flush()
        return subprocess.run(command, cwd=cwd, stdout=out, stderr=subprocess.STDOUT).returncode


def first_error(log):
    text = log.read_text(encoding="utf-8", errors="replace") if log.exists() else ""
    for line in text.splitlines():
        if re.search(r"\b(error|Error|FAILED|undefined reference)\b", line):
            return line.strip()[:300]
    return ""


def test_version(version, work, cache, pins, jobs):
    started = time.time()
    archive, digest = download(version, cache, pins)
    sdk = extract(archive, work / "sdk" / version)
    apply_sdk_fixes(sdk)
    build = work / "build" / version
    log = work / "logs" / f"{version}.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    log.unlink(missing_ok=True)
    if build.exists():
        shutil.rmtree(build)
    result = {"version": version, "sha256": digest, "configure": False, "builds": False,
              "tests": {"passed": 0, "total": 0}, "error": ""}
    configure = ["cmake", "-S", str(ROOT), "-B", str(build), "-G", "Ninja", "-DCMAKE_BUILD_TYPE=Release",
                 f"-DANGELSCRIPT_SDK={sdk}"]
    if os.environ.get("ASDEBUGGER_DIR"):
        configure.append(f"-DASDEBUGGER_DIR={os.environ['ASDEBUGGER_DIR']}")
    if run(configure, ROOT, log) == 0:
        result["configure"] = True
        if run(["cmake", "--build", str(build), "--parallel", str(jobs)], ROOT, log) == 0:
            result["builds"] = True
            run(["ctest", "--test-dir", str(build), "--output-on-failure"], ROOT, log)
            summary = re.findall(r"(\d+)% tests passed, (\d+) tests failed out of (\d+)",
                                 log.read_text(encoding="utf-8", errors="replace"))
            if summary:
                _, failed, total = map(int, summary[-1])
                result["tests"] = {"passed": total - failed, "total": total}
    if not result["builds"]:
        result["error"] = first_error(log)
    result["seconds"] = round(time.time() - started)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--list", action="store_true", help="print the official versions and exit")
    parser.add_argument("--versions", help="comma separated versions")
    parser.add_argument("--from", dest="start", help="every official version from this one up")
    parser.add_argument("--work", default=str(ROOT / "build" / "matrix"))
    parser.add_argument("--cache", default=None)
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    parser.add_argument("--out", default=str(ENGINES / "matrix.json"))
    args = parser.parse_args()

    if args.list:
        print("\n".join(official_versions()))
        return 0
    if args.versions:
        versions = args.versions.split(",")
    elif args.start:
        versions = [v for v in official_versions() if version_key(v) >= version_key(args.start)]
    else:
        parser.error("pass --versions, --from or --list")

    work = Path(args.work)
    cache = Path(args.cache) if args.cache else work / "cache"
    pins_path = ENGINES / "versions.json"
    pins = load(pins_path, {})
    out = Path(args.out)
    matrix = {row["version"]: row for row in load(out, [])}
    for version in versions:
        print(f"== AngelScript {version}", flush=True)
        try:
            row = test_version(version, work, cache, pins, args.jobs)
        except Exception as exc:  # a missing archive or a broken zip is a result, not a crash
            row = {"version": version, "configure": False, "builds": False,
                   "tests": {"passed": 0, "total": 0}, "error": f"{type(exc).__name__}: {exc}"}
        matrix[version] = row
        print(json.dumps(row), flush=True)
        save(pins_path, pins)
        save(out, sorted(matrix.values(), key=lambda r: version_key(r["version"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
