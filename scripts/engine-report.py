#!/usr/bin/env python3
"""Writes docs/ENGINE_VERSIONS.md from engines/matrix.json."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
matrix = json.loads((ROOT / "engines" / "matrix.json").read_text(encoding="utf-8"))


def key(version):
    return [int(p) if p.isdigit() else p for p in re.split(r"[.]|(?<=\d)(?=[a-z])", version)]


def number(version):
    major, minor, patch = (int(p) for p in re.match(r"(\d+)[.](\d+)[.](\d+)", version).groups())
    return major * 10000 + minor * 100 + patch


def tier(row):
    if not row["builds"]:
        return "Unsupported"
    if row["tests"]["passed"] != row["tests"]["total"]:
        return "Partial"
    if number(row["version"]) >= 23600:
        return "Full"
    return "Run and check"


# Causes seen in the logs of scripts/engine-matrix.py for the partial releases.
CAUSES = {
    "2.26.0": "the engine crashes (segmentation fault) in 9 tests; fixed in 2.26.2",
    "2.26.1": "the engine crashes (segmentation fault) in 9 tests; fixed in 2.26.2",
    "2.31.0": "the engine crashes (segmentation fault) in 2 tests; fixed in 2.31.1",
    "2.20.0": "the engine crashes (segmentation fault) in 11 tests",
    "2.20.1": "the engine crashes (segmentation fault) in 11 tests",
    "2.20.2": "3 tests fail: this release lacks script features the tests use (global initializers with calls, add-on join)",
    "2.20.3": "3 tests fail: this release lacks script features the tests use (global initializers with calls, add-on join)",
    "2.21.0": "1 test fails: this release lacks a script feature the test uses",
    "2.22.0": "cli-stdlib: float results of native functions read as 0 on Linux x64 (sqrt, parseFloat); a bug of this release",
    "2.22.1": "cli-stdlib: float results of native functions read as 0 on Linux x64 (sqrt, parseFloat); a bug of this release",
    "2.22.2": "cli-stdlib: float results of native functions read as 0 on Linux x64 (sqrt, parseFloat); a bug of this release",
    "2.23.0": "cli-stdlib: float results of native functions read as 0 on Linux x64 (sqrt, parseFloat); a bug of this release",
}

rows = ["| AngelScript | Support | Builds | Tests | Debugger (DAP) | Note |", "| --- | --- | --- | --- | --- | --- |"]
for row in sorted(matrix, key=lambda r: key(r["version"]), reverse=True):
    tests = f"{row['tests']['passed']}/{row['tests']['total']}" if row["builds"] else "-"
    dap = "yes" if row["builds"] and number(row["version"]) >= 23600 else "no"
    note = ""
    if not row["builds"]:
        note = row["error"].split(": error:")[-1][:80] if ": error:" in row["error"] else row["error"][:80]
        note = "the CLI runtime uses the function API of 2.22 and later (GetFunctionByDecl); not ported to the function-id API of this release"
    elif row["tests"]["passed"] != row["tests"]["total"]:
        failed = row["tests"]["total"] - row["tests"]["passed"]
        note = CAUSES.get(row["version"], f"{failed} of {row['tests']['total']} tests fail on this release")
    rows.append(f"| {row['version']} | {tier(row)} | {'yes' if row['builds'] else 'no'} | {tests} | {dap} | {note} |")

text = f"""# AngelScript engine versions

The CLI builds against any official release from [angelcode.com](https://www.angelcode.com/angelscript/downloads.html). This table is the result of `scripts/engine-matrix.py`, which downloads each release, checks its SHA-256 against `engines/versions.json`, builds the CLI on Linux x64 and runs the test suite.

- **Full**: runs, checks and debugs scripts. The debugger needs the context and function introspection of 2.36 and later.
- **Run and check**: runs and checks scripts. `--dap-port` reports that debugging needs 2.36.0 or later. Releases before 2.33 skip the tests for the `filesystem` and `datetime` add-ons, whose API differs.
- **Partial**: builds, but some of the CLI's tests fail on that release. Prefer the nearest newer release listed as Run and check or Full.
- **Unsupported**: the release does not build. Releases before 2.22 run through the function-id API, and two one-line fixes are applied to the extracted copy of 2.20 to 2.21 and 2.24 to 2.25 (see `scripts/engine-matrix.py`).

`angelscript --dump-predefined` needs 2.39.0 or later.

{chr(10).join(rows)}

Only versions that appear in the table were tested. Run `python scripts/engine-matrix.py --versions X.Y.Z` to test another one, and `python scripts/engine-report.py` to refresh this page.
"""
(ROOT / "docs" / "ENGINE_VERSIONS.md").write_text(text, encoding="utf-8", newline="\n")
print("wrote docs/ENGINE_VERSIONS.md")
