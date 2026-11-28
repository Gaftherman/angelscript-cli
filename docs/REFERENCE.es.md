# Referencia

**[English](REFERENCE.md)** | **[Español](REFERENCE.es.md)**

## Comandos

| Comando | Hace |
| --- | --- |
| `asc script.as [args]` | Ejecuta `main()`. Los argumentos llegan al script con `getArgs()` |
| `asc --check script.as` | Solo compila |
| `asc --dap-port 9002 script.as` | Espera un depurador en el puerto 9002 y luego ejecuta |
| `asc --version`, `asc --help` | Muestra la versión o el uso |

Códigos de salida: **0** éxito o `void main()`, **1** error de compilación o de ejecución, **2** línea de comandos inválida. Un script con `int main()` aporta su propio código.

Incluido: cadenas y utilidades de cadenas, arrays, diccionarios, matemáticas, archivos, sistema de archivos, fecha y hora, utilidades de excepciones, `print`, `println`, `getArgs` y sockets TCP (`tcpConnect`, `tcpListen`).

## Ejemplos

| Script | Muestra |
| --- | --- |
| [`hello.as`](../examples/hello.as) | `getArgs()` y `println` |
| [`files.as`](../examples/files.as) | Escribir, leer, medir y borrar un archivo |
| [`sum.as`](../examples/sum.as) | Argumentos y el código de salida de `int main()` |
| [`tcp-echo.as`](../examples/tcp-echo.as) | Un cliente y un servidor TCP en un script. El puerto `0` elige uno libre, y la conexión que ya espera en la cola basta para probar ambos lados con un solo script |
| [`strings.as`](../examples/strings.as) | Dividir, unir, subcadenas, búsqueda y formato de números |
| [`listdir.as`](../examples/listdir.as) | Crear una carpeta, listar sus archivos ordenados y borrarla |
| [`dates.as`](../examples/dates.as) | Crear una fecha, sumar tiempo, comparar y restar |

## VS Code

1. Instala la [extensión de AngelScript](https://marketplace.visualstudio.com/items?itemName=Gaftherman.angelscript-gaftherman) y abre un archivo `.as`.
2. Añade esto a `configurations` en `.vscode/launch.json`:

```json
{ "type": "angelscript", "request": "launch", "name": "Run script", "program": "${file}" }
```

3. Pulsa F5. La extensión busca `angelscript`, `asc` o `angelscript-cli` en el PATH. Define `angelscript.runner.path` para usar otro ejecutable.

### Soporte en el editor

[`examples/angelscript-cli.as.predefined`](../examples/angelscript-cli.as.predefined) describe cada tipo y función que registra la CLI (`string`, `array`, `dictionary`, `file`, `datetime`, `filesystem`, `TcpSocket`, `println`, `getArgs` y más), así que [AngelLSP](https://github.com/angelscript-tools/angelscript-lsp) revisa tus scripts sin marcar esos nombres como desconocidos. [`examples/angelscript.rules.json`](../examples/angelscript.rules.json) declara la versión del motor. Regenera el stub para otra compilación con `angelscript --dump-predefined > mi.as.predefined`.

## Depurar un script

Ejecuta el script con `--dap-port` y conecta VS Code:

```text
> asc --dap-port 9002 script.as
DAP listening on 127.0.0.1:9002
```

Añade esto a `configurations` en `.vscode/launch.json`, pon un punto de interrupción y pulsa F5:

```json
{ "type": "angelscript", "request": "attach", "name": "Attach to asc", "host": "127.0.0.1", "port": 9002, "protocol": "dap" }
```

<p align="center"><img src="https://raw.githubusercontent.com/angelscript-tools/angelscript-dap/main/docs/images/debugger-cli.gif" alt="VS Code conectado a un script que asc ejecuta en el Símbolo del sistema, avanzando paso a paso por addBonus" width="720"></p>

El depurador necesita AngelScript 2.36.0 o posterior (consulta [ENGINE_VERSIONS.md](https://github.com/angelscript-tools/angelscript-engine/blob/main/docs/ENGINE_VERSIONS.md)) y viene de [angelscript-dap](https://github.com/angelscript-tools/angelscript-dap). `--no-jit` y las sesiones del depurador usan el intérprete.
