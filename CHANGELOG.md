# Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0.0] - 2026-11-24

First release.

### Added

- The `angelscript` command, also available as `asc` and `angelscript-cli`, runs AngelScript 2.39 scripts with arguments, relative includes and a compile-only mode.
- Standard library add-ons, the print, println and getArgs functions, and TCP sockets: `tcpConnect`, `tcpListen`, `TcpSocket` and `TcpListener`.
- Runnable examples in `examples/` for files, folders, strings, dates, exit codes and TCP, covered by the test suite.
- Debug Adapter Protocol sessions for VS Code.
- A setup program for Windows (Inno Setup, with an optional PATH entry and an uninstaller), a `.pkg` for macOS and a `.deb` for Linux, built on every release and listed in `SHA256SUMS`.
- Windows x64, Linux x64 and arm64, and macOS x64 and arm64 archives with SHA-256 checksums, and PowerShell and POSIX shell installers with offline installation and uninstall.
- `THIRD_PARTY_NOTICES.md` with the licenses of AngelScript, asdebugger, cppdap and nlohmann/json, included in every package.
- English and Spanish READMEs with terminal demonstrations and step-by-step installation screenshots.
- The release is created automatically when the version in `CMakeLists.txt` has no tag yet.
- The CLI builds against official AngelScript releases from angelcode.com, not only the bundled 2.39.0. `scripts/engine-matrix.py` downloads each release, checks its pinned SHA-256, builds and tests it; three one-line compatibility fixes are applied to the extracted copy only. `docs/ENGINE_VERSIONS.md` lists all 43 releases from 2.20.0, and all of them build: full support from 2.36.0 with the debugger, run and check for the releases that pass every test, and the rest partial with their causes.
- The installers take `--engine X.Y.Z` (`-Engine` on Windows, or `ANGELSCRIPT_ENGINE_VERSION`) to install a build against another release side by side as `angelscript-X.Y.Z`. `scripts/build-engine.py` builds any official release from source. CI builds and packages 2.38.0, 2.37.0, 2.36.1, 2.35.1, 2.33.0 and 2.30.2 for every platform on main, and the release attaches them. The Windows setup program offers those builds on a components page, built from the CI artifacts (`package-installer.ps1 -EngineDir`).
- `examples/angelscript-cli.as.predefined` and `examples/angelscript.rules.json` make AngelLSP check the examples with no unknown names. The README adds an animated terminal capture and a plain Command Prompt capture.
- `angelscript --dump-predefined` prints every type and function a script sees as an `.as.predefined` stub, for the engine the binary was built with (2.39.0 or later).

[Unreleased]: https://github.com/Gaftherman/angelscript-cli/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Gaftherman/angelscript-cli/releases/tag/v1.0.0
