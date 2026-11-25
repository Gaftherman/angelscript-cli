# Roadmap

## Phase 2 · Package management

Each project has an `as.json` manifest with `name`, `version` and a `dependencies` map. Each key is a GitHub repository in `user/repo` form and its value is a tag. The package manager accepts `user/repo@tag`, resolves the tag to a commit, then fetches the GitHub tarball for that commit. It installs the contents under `as_modules/<user>/<repo>/`.

Commit `as.lock` with the project. Each entry records the repository, tag, resolved commit and SHA-256 of the archive. Reinstalls use the locked commit and verify the archive hash before extraction. An explicit dependency update can resolve a tag again and replace its lock entry. Cache verified archives by hash so locked projects can reinstall offline. Report which dependency is missing if the cache cannot satisfy an offline install.

Use the existing `IncludeResolver`. For `#include "user/repo/file.as"`, try the matching dependency and its subpath under the project's `as_modules` directory before the existing relative lookup from the containing script. [ScriptLoader.h](../src/runtime/ScriptLoader.h)

Extend the existing command registry. [Commands.cpp](../src/cli/Commands.cpp)

- **init** creates a starter manifest.
- **install** restores the dependency tree from the manifest and lockfile. With a `user/repo@tag` argument it adds the dependency and updates the lock.
- **run** continues to run explicit scripts and uses the project-aware include resolver when the script belongs to a project.

The installer runs no package scripts. Pin hashes in the lockfile, validate package paths before extraction and reject entries that can escape the destination.

### Open questions

- Should the first release resolve transitive dependencies? If so, how should it handle two tags for the same repository?
- How should projects choose a default script for run, and how should nested manifests affect project discovery?
- Where should the cache live on each OS, and when should unused archives be pruned?

## JIT

`JitProvider` selects the JIT at build time (`ANGELSCRIPT_CLI_JIT`). The default is `NullJit`, the interpreter. `-DANGELSCRIPT_CLI_JIT=angelsea` builds [angelsea](https://github.com/asumagic/angelsea) in and passes the whole test suite on Windows x64 and Linux x64 with AngelScript 2.39. The interpreter stays active in DAP sessions and with `--no-jit`, because angelsea does not preserve breakpoints, stepping or inspection (it compiles without line cues).

The three existing AngelScript JITs, read from their sources:

| JIT | Backend and targets | AngelScript | License | What it lacks |
| --- | --- | --- | --- | --- |
| [angelsea](https://github.com/asumagic/angelsea) | C translated to native code by MIR. Windows (MSVC, MinGW) and Linux x86-64; arm64 on Linux and macOS (experimental). | 2.37 and later (`asIJITCompilerV2`); it pins 2.38.0. 2.38 and 2.39 have the same bytecodes and JIT interface. | BSD-2-Clause (MIR and fmt: MIT) | Alpha. Falls back to the interpreter for `SUSPEND`, `CallPtr`, `FuncPtr`, `ALLOC`/`FREE`, list and `POW` instructions. No 32-bit x86 and no macOS x64. Needs a fork of MIR. Reads the engine's internal headers. |
| [BlindMindStudios JIT](https://github.com/BlindMindStudios/AngelScript-JIT-Compiler) | Hand-written x86 and x86-64 emitter for Windows and Linux. | 2.31.0 (`asIJITCompiler`, the first interface). | MIT | Unmaintained since 2016. It predates `asBC_TryBlock` (try/catch, 2.33), has open x64 call bugs, and has no arm64. |
| [sven_jit](https://github.com/DrAbcOfficial/sven_jit) | A Metamod plugin for the Sven Co-op server over `angelscript_jit_x86` (AsmJit). 32-bit x86 only. | 2.36.1 | GPL-3.0 | Not a library: it patches Sven Co-op's own AngelScript. GPL would make a binary that links it GPL, and it has no x64 or arm64. |

Only angelsea fits this CLI: it is a library, its license is compatible with MIT, and it supports the current engine. Before it can be enabled by default it needs the debugger fixtures with a JIT-aware policy, release builds for each target, and a beta release.
