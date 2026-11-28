# Reference

**[English](REFERENCE.md)** | **[Español](REFERENCE.es.md)**

## Commands

| Command | Does |
| --- | --- |
| `asc script.as [args]` | Run `main()`. Arguments reach the script through `getArgs()` |
| `asc --check script.as` | Compile only |
| `asc --dap-port 9002 script.as` | Wait for a debugger on port 9002, then run |
| `asc --version`, `asc --help` | Print the version or the usage |

Exit codes: **0** success or `void main()`, **1** compile or runtime error, **2** invalid command line. A script with `int main()` supplies its own code.

Built in: strings and string utilities, arrays, dictionaries, math, files, filesystem, date and time, exception helpers, `print`, `println`, `getArgs` and TCP sockets (`tcpConnect`, `tcpListen`).

## Examples

| Script | Shows |
| --- | --- |
| [`hello.as`](../examples/hello.as) | `getArgs()` and `println` |
| [`files.as`](../examples/files.as) | Write, read, size and delete a file |
| [`sum.as`](../examples/sum.as) | Arguments and the exit code of `int main()` |
| [`tcp-echo.as`](../examples/tcp-echo.as) | A TCP client and server in one script. Port `0` picks a free port, and the connection already waiting in the queue lets one script test both sides |
| [`strings.as`](../examples/strings.as) | Split, join, substrings, search and number formatting |
| [`listdir.as`](../examples/listdir.as) | Create a folder, list its files sorted, remove it |
| [`dates.as`](../examples/dates.as) | Build a date, add time, compare and subtract |

## VS Code

1. Install the [AngelScript extension](https://marketplace.visualstudio.com/items?itemName=Gaftherman.angelscript-gaftherman) and open a `.as` file.
2. Add this to `configurations` in `.vscode/launch.json`:

```json
{ "type": "angelscript", "request": "launch", "name": "Run script", "program": "${file}" }
```

3. Press F5. The extension finds `angelscript`, `asc` or `angelscript-cli` on PATH. Set `angelscript.runner.path` to use another executable.

### Editor support

[`examples/angelscript-cli.as.predefined`](../examples/angelscript-cli.as.predefined) describes every type and function the CLI registers (`string`, `array`, `dictionary`, `file`, `datetime`, `filesystem`, `TcpSocket`, `println`, `getArgs` and more), so [AngelLSP](https://github.com/angelscript-tools/angelscript-lsp) checks your scripts without reporting those names as unknown. [`examples/angelscript.rules.json`](../examples/angelscript.rules.json) declares the engine version. Regenerate the stub for another build with `angelscript --dump-predefined > my.as.predefined`.

## Debug a script

Run the script with `--dap-port` and attach VS Code to it:

```text
> asc --dap-port 9002 script.as
DAP listening on 127.0.0.1:9002
```

Add this to `configurations` in `.vscode/launch.json`, set a breakpoint and press F5:

```json
{ "type": "angelscript", "request": "attach", "name": "Attach to asc", "host": "127.0.0.1", "port": 9002, "protocol": "dap" }
```

<p align="center"><img src="https://raw.githubusercontent.com/angelscript-tools/angelscript-dap/main/docs/images/debugger-cli.gif" alt="VS Code attached to a script that asc runs in Command Prompt, stepping through addBonus" width="720"></p>

The debugger needs AngelScript 2.36.0 or later (see [ENGINE_VERSIONS.md](https://github.com/angelscript-tools/angelscript-engine/blob/main/docs/ENGINE_VERSIONS.md)) and comes from [angelscript-dap](https://github.com/angelscript-tools/angelscript-dap). `--no-jit` and debugger sessions use the interpreter.
