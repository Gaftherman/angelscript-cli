# Compilar

**[English](BUILDING.md)** | **[Español](BUILDING.es.md)**

Usa un compilador C++20, CMake 3.21+ y Ninja. Usa una terminal de desarrollador x64 para MSVC. Node.js habilita la prueba de DAP. Usa una terminal de desarrollador x86 (`amd64_x86`) para **windows-x86** e instala `g++-multilib` para **linux-x86**. Elige **windows-x64**, **windows-x86**, **linux-x64**, **linux-x86**, **linux-arm64** o **macos**.

```sh
git clone https://github.com/angelscript-tools/angelscript-cli.git
cd angelscript-cli
git submodule update --init
cmake --preset windows-x64
cmake --build --preset windows-x64
ctest --preset windows-x64
```

## JIT (opcional)

El intérprete es lo predeterminado. El JIT es [angelscript-jit](https://github.com/angelscript-tools/angelscript-jit), una bifurcación de [angelsea](https://github.com/asumagic/angelsea) que se mantiene funcionando con la versión actual de AngelScript. Necesita AngelScript 2.33 o posterior y un destino de 64 bits (Windows o Linux x86-64) o arm64 (experimental). Descarga sus dependencias y activa la opción:

```sh
git submodule update --init external/angelscript-jit
git -C external/angelscript-jit submodule update --init vendor/mir vendor/fmt
cmake --preset windows-x64 -DANGELSCRIPT_CLI_JIT=angelsea
```

`angelscript --version` termina entonces con `jit: angelsea`. `--no-jit` y las sesiones del depurador (`--dap-port`) siguen usando el intérprete. El JIT es software alfa; [la hoja de ruta](ROADMAP.md) (en inglés) lo compara con los otros JIT de AngelScript.

## Por adelantado (AOT)

Para evitar la compilación del JIT al arrancar, compila el script por adelantado. `--aot-export` escribe el C, lo compilas con clang o gcc y `--aot` lo carga (en Windows usa `-DASEA_ABI_MSVC=1` y un `.dll`):

```sh
angelscript --aot-export game game.as
clang -shared -O2 -DASEA_SUPPORT=1 -fPIC game.c -o game.so
angelscript --aot game game.as
```

La biblioteca solo sirve para la misma compilación de la CLI y el mismo script; si no, sus funciones se omiten y se ejecutan con normalidad.

## Otras versiones de AngelScript

La versión actual se compila tal cual. Las anteriores las descarga, verifica con un SHA-256 y parchea [angelscript-engine](https://github.com/angelscript-tools/angelscript-engine) (`external/angelscript-engine`):

```sh
python scripts/build-engine.py 2.36.1
python scripts/build-engine.py 2.39.0 --jit
```

Cada release publica además una compilación por cada versión de AngelScript compatible (y una con JIT desde la 2.33), y el instalador de Windows las ofrece. [ENGINE_VERSIONS.md](https://github.com/angelscript-tools/angelscript-engine/blob/main/docs/ENGINE_VERSIONS.md) indica qué admite cada una.
