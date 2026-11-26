# Building

**[English](BUILDING.md)** | **[Español](BUILDING.es.md)**

Use a C++20 compiler, CMake 3.21+ and Ninja. Use an x64 developer terminal for MSVC. Node.js enables the DAP test. Use an x86 developer terminal (`amd64_x86`) for **windows-x86**, and install `g++-multilib` for **linux-x86**. Choose **windows-x64**, **windows-x86**, **linux-x64**, **linux-x86**, **linux-arm64** or **macos**.

```sh
git clone https://github.com/Gaftherman/angelscript-cli.git
cd angelscript-cli
git submodule update --init
cmake --preset windows-x64
cmake --build --preset windows-x64
ctest --preset windows-x64
```

## JIT (optional)

The interpreter is the default. The JIT is [angelscript-jit](https://github.com/Gaftherman/angelscript-jit), a fork of [angelsea](https://github.com/asumagic/angelsea) kept working on the current AngelScript release. It needs AngelScript 2.33 or later and a 64-bit Windows or Linux x86-64 target, or arm64 (experimental). Fetch its dependencies and set the option:

```sh
git submodule update --init external/angelscript-jit
git -C external/angelscript-jit submodule update --init vendor/mir vendor/fmt
cmake --preset windows-x64 -DANGELSCRIPT_CLI_JIT=angelsea
```

`angelscript --version` then ends with `jit: angelsea`. `--no-jit` and debugger sessions (`--dap-port`) keep using the interpreter. The JIT is alpha software; [the roadmap](ROADMAP.md) compares it with the other AngelScript JITs.

## Ahead of time

To skip the JIT compile at start-up, compile the script ahead of time. `--aot-export` writes the C, you build it with clang or gcc, and `--aot` loads it (use `-DASEA_ABI_MSVC=1` and a `.dll` on Windows):

```sh
angelscript --aot-export game game.as
clang -shared -O2 -DASEA_SUPPORT=1 -fPIC game.c -o game.so
angelscript --aot game game.as
```

The library only fits the same build of the CLI and the same script; otherwise its functions are skipped and run normally.

## Other AngelScript releases

The current release builds as it is. Older ones are downloaded, checked against a SHA-256 and patched by [angelscript-engine](https://github.com/Gaftherman/angelscript-engine) (`external/angelscript-engine`):

```sh
python scripts/build-engine.py 2.36.1
python scripts/build-engine.py 2.39.0 --jit
```

Every release also publishes a build for each supported AngelScript release (and a JIT build from 2.33), and the Windows setup offers them. [ENGINE_VERSIONS.md](https://github.com/Gaftherman/angelscript-engine/blob/main/docs/ENGINE_VERSIONS.md) lists what each one supports.
