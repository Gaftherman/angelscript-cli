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

[Unreleased]: https://github.com/Gaftherman/angelscript-cli/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Gaftherman/angelscript-cli/releases/tag/v1.0.0
