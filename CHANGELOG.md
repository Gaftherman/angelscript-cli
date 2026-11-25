# Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.1.0] - 2026-11-25

### Added

- Build against official AngelScript releases from 2.20 to 2.39 (`scripts/build-engine.py`) and publish a build for each supported engine with every release. [ENGINE_VERSIONS.md](https://github.com/Gaftherman/angelscript-engine/blob/main/docs/ENGINE_VERSIONS.md) lists what each version supports.
- Optional [angelsea](https://github.com/asumagic/angelsea) JIT: build with `-DANGELSCRIPT_CLI_JIT=angelsea` (AngelScript 2.37 or later, x86-64 or arm64). `angelscript --version` reports `jit: angelsea`; `--no-jit` and debugger sessions keep the interpreter. The `JIT` workflow builds and tests it without blocking CI.
- The Windows setup program has one checkbox per AngelScript release, so each `angelscript-<version>` can be installed on its own.
- Windows x86 and Linux x86 builds: archives, a Windows setup program and a Debian package for each, plus an engine build for every supported release.
- Support section in the README and a contributing guide in English and Spanish.

### Changed

- The engine fixes, SHA-256 pins and version matrix moved to [angelscript-engine](https://github.com/Gaftherman/angelscript-engine) (`external/angelscript-engine`). The engine builds run in their own workflow (`engine-builds.yml`) after a release is published and attach their assets to it, so a failing engine build no longer blocks the release.
- The debugger core now comes from the [angelscript-dap](https://github.com/Gaftherman/angelscript-dap) submodule (`external/angelscript-dap`).
- Spanish README and third-party notices moved to `docs/`.

### Fixed

- Builds on Linux arm64: C++-only flags no longer reach the assembly sources.
- Builds on macOS with the older engine releases: the clashing assembly labels are renamed in the extracted copy of the engine.
- The CI built the engine releases only for macOS x64 (a matrix `include` overwrote the other targets), so the Windows setup had no engine builds to bundle; every engine now builds on all seven targets and the CI runs each one on a sample script.
- The CLI links Winsock on Windows, so engine releases without a debugger (before 2.36) build there.
- AngelScript 2.30.2 and earlier link on 64-bit Windows: the MASM call-convention file is added to the engine build.
- Engine releases without native calls on arm64 (2.33 and earlier, and 2.35 and 2.36 on macOS) build in the engine's portable mode; add-ons that have no portable registration are left out of those builds.
- AngelScript 2.35.1 builds with Clang (macOS, Linux with clang); the extracted copy takes the Clang branch that 2.36.0 added to `WRAP_MFN_PR`.
- AngelScript 2.22.0 to 2.22.2, 2.23.0, 2.26.0 and 2.26.1 no longer return wrong float results on Linux x64: their call-convention source is taken from the next point release.

## [1.0.0] - 2026-11-24

First release.

### Added

- The `angelscript` command, also available as `asc` and `angelscript-cli`, runs AngelScript 2.39 scripts with arguments, relative includes and a compile-only mode.
- Standard library add-ons, the print, println and getArgs functions, and TCP sockets: `tcpConnect`, `tcpListen`, `TcpSocket` and `TcpListener`.
- Runnable examples in `examples/` for files, folders, strings, dates, exit codes and TCP, covered by the test suite.
- Debug Adapter Protocol sessions for VS Code.
- A setup program for Windows (Inno Setup, with an optional PATH entry and an uninstaller), a `.pkg` for macOS and a `.deb` for Linux, built on every release and listed in `SHA256SUMS`.
- Windows x64, Linux x64 and arm64, and macOS x64 and arm64 archives with SHA-256 checksums, and PowerShell and POSIX shell installers with offline installation and uninstall.
- `THIRD_PARTY_NOTICES.md` with the licenses of AngelScript, the debugger core (angelscript-dap), cppdap and nlohmann/json, included in every package.
- English and Spanish READMEs with terminal demonstrations and step-by-step installation screenshots.
- The release is created automatically when the version in `CMakeLists.txt` has no tag yet.
- The CLI builds against official AngelScript releases from angelcode.com, not only the bundled 2.39.0. `scripts/engine-matrix.py` downloads each release, checks its pinned SHA-256, builds and tests it; three one-line compatibility fixes are applied to the extracted copy only. `docs/ENGINE_VERSIONS.md` lists all 43 releases from 2.20.0, and all of them build: full support from 2.36.0 with the debugger, run and check for the releases that pass every test, and the rest partial with their causes.
- The installers take `--engine X.Y.Z` (`-Engine` on Windows, or `ANGELSCRIPT_ENGINE_VERSION`) to install a build against another release side by side as `angelscript-X.Y.Z`. `scripts/build-engine.py` builds any official release from source. CI builds and packages 2.38.0, 2.37.0, 2.36.1, 2.35.1, 2.33.0 and 2.30.2 for every platform on main, and the release attaches them. The Windows setup program offers those builds on a components page, built from the CI artifacts (`package-installer.ps1 -EngineDir`).
- `examples/angelscript-cli.as.predefined` and `examples/angelscript.rules.json` make AngelLSP check the examples with no unknown names. The README adds an animated terminal capture and a plain Command Prompt capture.
- The Debug Adapter Protocol core comes from the [angelscript-dap](https://github.com/Gaftherman/angelscript-dap) repository (a submodule), shared with the example project and the asdebugger Sven Co-op plugin. The assembly sources of the arm64 call convention no longer receive the C++ compatibility flags, and engine releases before 2.39 get their global asm labels prefixed in the extracted copy so they build on Clang.
- 2.22.0 to 2.22.2, 2.23.0, 2.26.0 and 2.26.1 return wrong float results or crash on Linux x64 in their own `as_callfunc_x64_gcc.cpp`. The extracted copy takes that file (and `as_callfunc.h` for 2.22) from the next point release, so 2.23.0, 2.26.0 and 2.26.1 now pass every test; the 2.22 releases and the rest of the partial list (2.20.x, 2.21.0, 2.31.0) stay documented with their causes.
- `CONTRIBUTING.md` with a Spanish version, a Support section and a list of related projects in the READMEs. The Spanish README, the third-party notices and the roadmap live in `docs/`.
- `angelscript --dump-predefined` prints every type and function a script sees as an `.as.predefined` stub, for the engine the binary was built with (2.39.0 or later).

[Unreleased]: https://github.com/Gaftherman/angelscript-cli/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/Gaftherman/angelscript-cli/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Gaftherman/angelscript-cli/releases/tag/v1.0.0
