# Contribuir a AngelScript CLI

**[English](../CONTRIBUTING.md)** | **[Español](CONTRIBUTING.es.md)**

Gracias por ayudar. Se agradecen los informes de errores, las correcciones, la documentación y los ejemplos.

## Informar de un problema

Abre una [incidencia](https://github.com/angelscript-tools/angelscript-cli/issues) con la versión que usas, tu sistema operativo, los pasos para reproducirlo y la salida que viste. Lo que más ayuda es un script de pocas líneas que reproduzca el problema.

## Proponer un cambio

1. Haz un fork del repositorio y crea una rama desde `main`.
2. Mantén cada cambio pequeño y enfocado, con pruebas cuando cambie el comportamiento.
3. Escribe los mensajes de commit como `tipo(ámbito): descripción breve en imperativo` sin punto final. Tipos: `feat`, `fix`, `test`, `perf`, `refactor`, `style`, `docs`, `chore`.
4. Abre una pull request que explique qué cambió y cómo lo comprobaste.

## Compilar y probar

Usa un compilador C++20, CMake 3.21+ y Ninja. Elige **windows-x64**, **windows-x86**, **linux-x64**, **linux-x86** (necesita `g++-multilib`), **linux-arm64** o **macos**:

~~~sh
git clone https://github.com/angelscript-tools/angelscript-cli.git
cd angelscript-cli
git submodule update --init
cmake --preset windows-x64
cmake --build --preset windows-x64
ctest --preset windows-x64
~~~

Los parches del SDK, los hashes SHA-256 y la matriz de motores viven en [angelscript-engine](https://github.com/angelscript-tools/angelscript-engine), que se clona en `external/angelscript-engine`. Para comprobar otra versión de AngelScript, ejecuta `python scripts/build-engine.py X.Y.Z`; si la versión es nueva, fíjala primero allí con `python external/angelscript-engine/scripts/prepare-sdk.py X.Y.Z --out build/sdk --pin`. La versión incluida (`external/angelscript`, la actual) se compila tal cual y no necesita ese repositorio. El JIT es [angelscript-jit](https://github.com/angelscript-tools/angelscript-jit), que se clona en `external/angelscript-jit`; `python scripts/build-engine.py X.Y.Z --jit` compila una versión con él, y `scripts/plan-engine-builds.py` lista las versiones y destinos que compila el workflow de engines.

## Estilo

C++20 con RAII y punteros inteligentes. Sigue `.editorconfig` (4 espacios, LF). Da formato a Python con `ruff format`.

## Licencia

Al contribuir aceptas que tu trabajo se publique bajo la [licencia MIT](../LICENSE).

## Proyectos relacionados

| Proyecto | Uso |
| --- | --- |
| [angelscript-dap](https://github.com/angelscript-tools/angelscript-dap) | El núcleo del depurador |
| [angelscript-debugger-example](https://github.com/angelscript-tools/angelscript-debugger-example) | Una aplicación que muestra cómo usar el depurador |
| [angelscript-cli](https://github.com/angelscript-tools/angelscript-cli) | Ejecuta, comprueba y depura scripts desde la terminal |
| [angelscript-lsp](https://github.com/angelscript-tools/angelscript-lsp) | Soporte del editor para VS Code |
