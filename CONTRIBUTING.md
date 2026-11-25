# Contributing to AngelScript CLI

**[English](CONTRIBUTING.md)** | **[Español](docs/CONTRIBUTING.es.md)**

Thank you for helping. Bug reports, fixes, documentation and examples are all welcome.

## Report a problem

Open an [issue](https://github.com/Gaftherman/angelscript-cli/issues) with the version you use, your operating system, the steps to reproduce it and the output you saw. A script of a few lines that reproduces the problem helps most.

## Propose a change

1. Fork the repository and create a branch from `main`.
2. Keep each change small and focused, with tests when behaviour changes.
3. Write commit messages as `type(scope): short imperative description` without a trailing period. Types: `feat`, `fix`, `test`, `perf`, `refactor`, `style`, `docs`, `chore`.
4. Open a pull request that says what changed and how you checked it.

## Build and test

Use a C++20 compiler, CMake 3.21+ and Ninja. Choose **windows-x64**, **windows-x86**, **linux-x64**, **linux-x86** (needs `g++-multilib`), **linux-arm64** or **macos**:

~~~sh
git clone https://github.com/Gaftherman/angelscript-cli.git
cd angelscript-cli
git submodule update --init
cmake --preset windows-x64
cmake --build --preset windows-x64
ctest --preset windows-x64
~~~

The SDK fixes, the SHA-256 pins and the engine matrix live in [angelscript-engine](https://github.com/Gaftherman/angelscript-engine), checked out as `external/angelscript-engine`. To check another AngelScript release, run `python scripts/build-engine.py X.Y.Z`; if the release is new, pin it there first with `python external/angelscript-engine/scripts/prepare-sdk.py X.Y.Z --out build/sdk --pin`. The bundled release (`external/angelscript`, the current one) builds as it is and does not need that repository. The JIT is [angelscript-jit](https://github.com/Gaftherman/angelscript-jit), checked out as `external/angelscript-jit`; `python scripts/build-engine.py X.Y.Z --jit` builds a release with it, and `scripts/plan-engine-builds.py` lists the releases and targets that the engine workflow builds.

## Style

C++20 with RAII and smart pointers. Follow `.editorconfig` (4 spaces, LF). Format Python with `ruff format`.

## License

By contributing you agree that your work is released under the [MIT License](LICENSE).

## Related projects

| Project | Use |
| --- | --- |
| [angelscript-dap](https://github.com/Gaftherman/angelscript-dap) | The debugger core |
| [angelscript-debugger-example](https://github.com/Gaftherman/angelscript-debugger-example) | A host that shows how to use the debugger |
| [angelscript-cli](https://github.com/Gaftherman/angelscript-cli) | Run, check and debug scripts from the terminal |
| [angelscript-lsp](https://github.com/Gaftherman/angelscript-lsp) | Editor support for VS Code |
