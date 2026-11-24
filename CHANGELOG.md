# Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.2.0] - 2026-11-24

### Added

- TCP sockets in the standard library: `tcpConnect`, `tcpListen`, `TcpSocket` and `TcpListener`.
- Runnable examples in `examples/` for files, folders, strings, dates, exit codes and TCP, covered by the test suite.
- English and Spanish READMEs with the language switch and terminal demonstrations.

### Changed

- The program is now named `angelscript`. The installers also create the short `asc` and the previous `angelscript-cli` commands.
- Fix the macOS build by taking asdebugger with the `mincore` signature fix.

## [0.1.0] - 2026-11-24

### Added

- Standalone AngelScript 2.39 interpreter with script arguments, relative includes and a compile-only mode.
- Standard library add-ons and the print, println and getArgs functions.
- Debug Adapter Protocol sessions for VS Code.
- Windows x64, Linux x64 and arm64, and macOS x64 and arm64 release archives with SHA-256 checksums.
- PowerShell and POSIX shell installers with offline installation and uninstall.

[Unreleased]: https://github.com/Gaftherman/angelscript-cli/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/Gaftherman/angelscript-cli/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Gaftherman/angelscript-cli/releases/tag/v0.1.0
