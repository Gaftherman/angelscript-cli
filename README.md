# AngelScript CLI

**[English](README.md)** | **[Español](docs/README.es.md)**

Run, check and debug standalone AngelScript scripts from the terminal, the way you run Python or Node. One small program with files, strings, dates and TCP sockets built in.

~~~text
> asc hello.as
Hello, world!
~~~

## Install

### Windows

Download `angelscript-cli-1.2.0-windows-x64-setup.exe` from [Releases](https://github.com/Gaftherman/angelscript-cli/releases/latest) and run it. Use `angelscript-cli-1.2.0-windows-x86-setup.exe` on 32-bit Windows.

1. Accept the license.

<p align="center"><img src="docs/images/install-1-license.png" alt="Setup license page" width="520"></p>

2. Choose the folder. The default is inside your user profile and needs no administrator rights.

<p align="center"><img src="docs/images/install-2-folder.png" alt="Setup folder page" width="520"></p>

3. Choose the AngelScript release. Like Python, the setup installs one release at a time, as `angelscript`, `asc` and `angelscript-cli`; the newest one is selected. Each line says whether that release has a JIT build and which add-ons it lacks (the oldest releases have no `datetime` or `filesystem`). Under a release with a JIT build, tick **Use the JIT compiler** to install the JIT variant (experimental, 64-bit). Run the setup again at any time to replace the installed release with another one. The releases other than the newest appear once their builds are attached to the release, a few minutes after it is published.

<p align="center"><img src="docs/images/install-3-components.png" alt="Setup components page with one radio button per AngelScript release and a JIT checkbox" width="520"></p>

4. Keep **Add AngelScript to the PATH environment variable** checked.

<p align="center"><img src="docs/images/install-4-tasks.png" alt="Setup tasks page with the PATH option" width="520"></p>

5. Press **Install**, then **Finish**.

<p align="center"><img src="docs/images/install-6-finish.png" alt="Setup finished page" width="520"></p>

Open a new terminal and run `asc --version`. To remove it, use **Settings > Apps**. The setup is not code-signed yet, so Windows SmartScreen may show **Windows protected your PC**: choose **More info**, then **Run anyway**.

### macOS

Download `angelscript-cli-1.2.0-macos-arm64.pkg` (Apple silicon) or `angelscript-cli-1.2.0-macos-x64.pkg` (Intel) from [Releases](https://github.com/Gaftherman/angelscript-cli/releases/latest) and open it. It installs into `/usr/local/bin`. The package is not notarized yet: if macOS blocks it, right-click it and choose **Open**.

### Linux

~~~sh
$ sudo apt install ./angelscript-cli-1.2.0-linux-x64.deb
~~~

Use `linux-arm64` on ARM and `linux-x86` on 32-bit x86. Remove it with `sudo apt remove angelscript-cli`.

### Scripts, without administrator rights

~~~powershell
> irm https://raw.githubusercontent.com/Gaftherman/angelscript-cli/main/scripts/install.ps1 | iex
~~~

~~~sh
$ curl -fsSL https://raw.githubusercontent.com/Gaftherman/angelscript-cli/main/scripts/install.sh | sh
~~~

Open a new terminal. Three names run the same program: `angelscript`, the short `asc` and the older `angelscript-cli`. To pick the CLI version, set `ANGELSCRIPT_CLI_VERSION` in PowerShell or run `sh -s -- --version 1.2.0`. To pick the AngelScript release, set `ANGELSCRIPT_ENGINE_VERSION` (or run `sh -s -- --engine 2.36.1`); add `ANGELSCRIPT_CLI_JIT=1` (or `--jit`) for the JIT build. `--arch x64|x86|arm64` (or `ANGELSCRIPT_CLI_ARCH`) overrides the detected architecture. The chosen build replaces the installed one. To install by hand, extract the archive from [Releases](https://github.com/Gaftherman/angelscript-cli/releases/latest).

## Quick start

Create `hello.as`:

~~~angelscript
void main()
{
    array<string>@ args = getArgs();
    string name = args.length() > 0 ? args[0] : "world";
    println("Hello, " + name + "!");
}
~~~

~~~text
> asc hello.as
Hello, world!
> asc hello.as Ada
Hello, Ada!
> asc --check hello.as
~~~

`--check` compiles without running and exits with 0 when the script is clean.

## Examples

Every example lives in [`examples/`](examples).

### Files

~~~angelscript
int main()
{
    file notes;
    if (notes.open("notes.txt", "w") != 0)
        return 1;
    notes.writeString("first line\n");
    notes.writeString("second line\n");
    notes.close();

    if (notes.open("notes.txt", "r") != 0)
        return 1;
    while (!notes.isEndOfFile())
    {
        string line = notes.readLine();
        if (line.length() > 0)
            print("read: " + line);
    }
    notes.close();

    filesystem fs;
    println("size: " + fs.getSize("notes.txt") + " bytes");
    fs.deleteFile("notes.txt");
    return 0;
}
~~~

~~~text
> asc files.as
read: first line
read: second line
size: 23 bytes
~~~

### Exit codes

~~~angelscript
int main()
{
    array<string>@ args = getArgs();
    int total = 0;
    for (uint i = 0; i < args.length(); i++)
        total += parseInt(args[i]);
    println("sum = " + total);
    return total % 256;
}
~~~

~~~text
> asc sum.as 10 20 30
sum = 60
> echo %ERRORLEVEL%
60
~~~

### TCP sockets

~~~angelscript
void main()
{
    TcpListener@ server = tcpListen("127.0.0.1", 0);
    TcpSocket@ client = tcpConnect("127.0.0.1", server.port());
    TcpSocket@ peer = server.accept();

    client.send("hello over tcp\n");
    string request = peer.receiveLine();
    println("server got: " + request);
    peer.send("echo: " + request + "\n");
    println("client got: " + client.receiveLine());

    client.close();
    peer.close();
    server.close();
}
~~~

~~~text
> asc tcp-echo.as
server got: hello over tcp
client got: echo: hello over tcp
~~~

Port `0` picks a free port. `accept()` waits for the next client, and the connection already waiting in the queue is enough for a single script to test both sides.

### More

| Script | Shows |
| --- | --- |
| [`listdir.as`](examples/listdir.as) | Create a folder, list its files sorted, remove it |
| [`strings.as`](examples/strings.as) | Split, join, substrings, search and number formatting |
| [`dates.as`](examples/dates.as) | Build a date, add time, compare and subtract |

~~~text
> asc strings.as
words: 4
joined: AngelScript-makes-scripting-simple
first word: AngelScript
'simple' starts at: 28
padded: [000042]
float: 3.14
~~~

## Use with VS Code

1. Install the [AngelScript extension](https://marketplace.visualstudio.com/items?itemName=Gaftherman.angelscript-gaftherman) and open a `.as` file.
2. Add this to `configurations` in `.vscode/launch.json`:

~~~json
{ "type": "angelscript", "request": "launch", "name": "Run script", "program": "${file}" }
~~~

3. Press F5. The extension finds `angelscript`, `asc` or `angelscript-cli` on PATH. Set `angelscript.runner.path` to use another executable.

<p align="center"><img src="docs/images/vscode-files.png" alt="files.as open in VS Code with asc running it in the terminal" width="720"></p>
<p align="center"><em>The extension checks the code as you type. The terminal runs it with <code>asc</code>.</em></p>

<p align="center"><img src="docs/images/vscode-tcp-echo.png" alt="tcp-echo.as open in VS Code with its output in the terminal" width="720"></p>
<p align="center"><em>A TCP echo example and its output.</em></p>

<p align="center"><img src="docs/images/vscode-run.gif" alt="Typing `asc files.as` in the VS Code terminal" width="720"></p>

<p align="center"><img src="docs/images/cmd-run.png" alt="A plain Command Prompt running the same scripts" width="720"></p>

### Editor support

[`examples/angelscript-cli.as.predefined`](examples/angelscript-cli.as.predefined) describes every type and function the CLI registers (`string`, `array`, `dictionary`, `file`, `datetime`, `filesystem`, `TcpSocket`, `println`, `getArgs` and more), so [AngelLSP](https://github.com/Gaftherman/angelscript-lsp) checks your scripts without reporting those names as unknown. [`examples/angelscript.rules.json`](examples/angelscript.rules.json) declares the engine version. Regenerate the stub for another build with `angelscript --dump-predefined > my.as.predefined`.

### Debug a script

Run the script with `--dap-port` and attach VS Code to it:

~~~text
> asc --dap-port 9002 script.as
DAP listening on 127.0.0.1:9002
~~~

Add this to `configurations` in `.vscode/launch.json`, set a breakpoint and press F5:

~~~json
{ "type": "angelscript", "request": "attach", "name": "Attach to asc", "host": "127.0.0.1", "port": 9002, "protocol": "dap" }
~~~

<p align="center"><img src="https://raw.githubusercontent.com/Gaftherman/angelscript-dap/main/docs/images/debugger-cli.gif" alt="VS Code attached to a script that asc runs in Command Prompt, stepping through addBonus" width="720"></p>

The debugger needs AngelScript 2.36.0 or later (see [ENGINE_VERSIONS.md](https://github.com/Gaftherman/angelscript-engine/blob/main/docs/ENGINE_VERSIONS.md)) and comes from [angelscript-dap](https://github.com/Gaftherman/angelscript-dap).

## Reference

| Command | Does |
| --- | --- |
| `asc script.as [args]` | Run `main()`. Arguments reach the script through `getArgs()` |
| `asc --check script.as` | Compile only |
| `asc --dap-port 9002 script.as` | Wait for a debugger on port 9002, then run |
| `asc --version`, `asc --help` | Print the version or the usage |

Exit codes: **0** success or `void main()`, **1** compile or runtime error, **2** invalid command line. A script with `int main()` supplies its own code.

Built in: strings and string utilities, arrays, dictionaries, math, files, filesystem, date and time, exception helpers, `print`, `println`, `getArgs` and TCP sockets (`tcpConnect`, `tcpListen`).

## Build from source

Use a C++20 compiler, CMake 3.21+ and Ninja. Use an x64 developer terminal for MSVC. Node.js enables the DAP test. Use an x86 developer terminal (`amd64_x86`) for **windows-x86**, and install `g++-multilib` for **linux-x86**. Choose **windows-x64**, **windows-x86**, **linux-x64**, **linux-x86**, **linux-arm64** or **macos**.

~~~sh
git clone https://github.com/Gaftherman/angelscript-cli.git
cd angelscript-cli
git submodule update --init
cmake --preset windows-x64
cmake --build --preset windows-x64
ctest --preset windows-x64
~~~

### JIT (optional)
The interpreter is the default. The JIT is [angelscript-jit](https://github.com/Gaftherman/angelscript-jit), a fork of [angelsea](https://github.com/asumagic/angelsea) kept working on the current AngelScript release. It needs AngelScript 2.37 or later and a 64-bit Windows or Linux x86-64 target, or arm64 (experimental). Fetch its dependencies and set the option:
~~~sh
git submodule update --init external/angelscript-jit
git -C external/angelscript-jit submodule update --init vendor/mir vendor/fmt
cmake --preset windows-x64 -DANGELSCRIPT_CLI_JIT=angelsea
~~~
`angelscript --version` then ends with `jit: angelsea`. `--no-jit` and debugger sessions (`--dap-port`) keep using the interpreter. The JIT is alpha software; [the roadmap](docs/ROADMAP.md) compares it with the other AngelScript JITs.
### Other AngelScript releases
The current release builds as it is. Older ones are downloaded, checked against a SHA-256 and patched by [angelscript-engine](https://github.com/Gaftherman/angelscript-engine) (`external/angelscript-engine`):
~~~sh
python scripts/build-engine.py 2.36.1
python scripts/build-engine.py 2.39.0 --jit
~~~
Every release also publishes a build for each supported AngelScript release (and a JIT build from 2.37), and the Windows setup offers them. [ENGINE_VERSIONS.md](https://github.com/Gaftherman/angelscript-engine/blob/main/docs/ENGINE_VERSIONS.md) lists what each one supports.
## Roadmap

[Package management and JIT](docs/ROADMAP.md)

## Credits

AngelScript CLI runs on the work of these projects. Their licenses are reproduced in [THIRD_PARTY_NOTICES.md](docs/THIRD_PARTY_NOTICES.md) and ship with every package.

| Project | License | Use |
| --- | --- | --- |
| [AngelScript](https://github.com/anjo76/angelscript) by Andreas Jönsson | zlib | The language and its runtime |
| [angelscript-dap](https://github.com/Gaftherman/angelscript-dap) | MIT | Debug Adapter Protocol core |
| [cppdap](https://github.com/google/cppdap) | Apache-2.0 | Debug Adapter Protocol library |
| [nlohmann/json](https://github.com/nlohmann/json) | MIT | JSON, through cppdap |

## License

[MIT](LICENSE)

## Support

Open an [issue](https://github.com/Gaftherman/angelscript-cli/issues) for the command line program, the installers and the engine versions listed in [ENGINE_VERSIONS.md](https://github.com/Gaftherman/angelscript-engine/blob/main/docs/ENGINE_VERSIONS.md). Include the output of `angelscript --version`, your operating system and a short script that reproduces the problem. Debugger problems go to [angelscript-dap](https://github.com/Gaftherman/angelscript-dap/issues), and editor problems to [angelscript-lsp](https://github.com/Gaftherman/angelscript-lsp/issues). To help, read [CONTRIBUTING.md](CONTRIBUTING.md).

## Related projects

| Project | Use |
| --- | --- |
| [angelscript-dap](https://github.com/Gaftherman/angelscript-dap) | The debugger core behind `--dap-port` |
| [angelscript-debugger-example](https://github.com/Gaftherman/angelscript-debugger-example) | A host that shows how to use the debugger |
| [angelscript-lsp](https://github.com/Gaftherman/angelscript-lsp) | Editor support for VS Code |
