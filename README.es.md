# AngelScript CLI

**[English](README.md)** | **[Español](README.es.md)**

Ejecuta, comprueba y depura scripts de AngelScript desde la terminal, como ejecutas Python o Node. Un programa pequeño con archivos, cadenas, fechas y sockets TCP incluidos.

~~~text
> asc hello.as
Hello, world!
~~~

## Instalación

### Windows

Descarga `angelscript-cli-1.0.0-windows-x64-setup.exe` desde [Releases](https://github.com/Gaftherman/angelscript-cli/releases/latest) y ejecútalo.

1. Acepta la licencia.

<p align="center"><img src="docs/images/install-1-license.png" alt="Página de licencia del instalador" width="520"></p>

2. Elige la carpeta. La predeterminada está en tu perfil de usuario y no necesita permisos de administrador.

<p align="center"><img src="docs/images/install-2-folder.png" alt="Página de carpeta del instalador" width="520"></p>

3. Deja marcada **Add AngelScript to the PATH environment variable** (añadir AngelScript a la variable PATH).

<p align="center"><img src="docs/images/install-3-tasks.png" alt="Página de tareas del instalador con la opción de PATH" width="520"></p>

4. Pulsa **Install** y después **Finish**.

<p align="center"><img src="docs/images/install-5-finish.png" alt="Página final del instalador" width="520"></p>

Abre una terminal nueva y ejecuta `asc --version`. Para quitarlo, usa **Configuración > Aplicaciones**. El instalador aún no está firmado, así que Windows SmartScreen puede mostrar **Windows protegió su PC**: elige **Más información** y después **Ejecutar de todas formas**.

### macOS

Descarga `angelscript-cli-1.0.0-macos-arm64.pkg` (Apple silicon) o `angelscript-cli-1.0.0-macos-x64.pkg` (Intel) desde [Releases](https://github.com/Gaftherman/angelscript-cli/releases/latest) y ábrelo. Se instala en `/usr/local/bin`. El paquete aún no está notarizado: si macOS lo bloquea, haz clic derecho y elige **Abrir**.

### Linux

~~~sh
$ sudo apt install ./angelscript-cli-1.0.0-linux-x64.deb
~~~

Usa `linux-arm64` en ARM. Para quitarlo, ejecuta `sudo apt remove angelscript-cli`.

### Scripts, sin permisos de administrador

~~~powershell
> irm https://raw.githubusercontent.com/Gaftherman/angelscript-cli/main/scripts/install.ps1 | iex
~~~

~~~sh
$ curl -fsSL https://raw.githubusercontent.com/Gaftherman/angelscript-cli/main/scripts/install.sh | sh
~~~

Abre una terminal nueva. Tres nombres ejecutan el mismo programa: `angelscript`, el corto `asc` y el anterior `angelscript-cli`. Para elegir una versión, define `ANGELSCRIPT_CLI_VERSION` en PowerShell o ejecuta `sh -s -- --version 1.0.0`. Para instalar a mano, extrae el archivo de [Releases](https://github.com/Gaftherman/angelscript-cli/releases/latest).

## Inicio rápido

Crea `hello.as`:

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

`--check` compila sin ejecutar y termina con 0 si el script está limpio.

## Ejemplos

Todos los ejemplos están en [`examples/`](examples).

### Archivos

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

### Códigos de salida

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

### Sockets TCP

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

El puerto `0` elige uno libre. `accept()` espera al siguiente cliente, y la conexión que ya espera en la cola basta para que un solo script pruebe ambos lados.

### Más

| Script | Muestra |
| --- | --- |
| [`listdir.as`](examples/listdir.as) | Crear una carpeta, listar sus archivos ordenados y borrarla |
| [`strings.as`](examples/strings.as) | Dividir, unir, subcadenas, búsqueda y formato de números |
| [`dates.as`](examples/dates.as) | Crear una fecha, sumar tiempo, comparar y restar |

~~~text
> asc strings.as
words: 4
joined: AngelScript-makes-scripting-simple
first word: AngelScript
'simple' starts at: 28
padded: [000042]
float: 3.14
~~~

## Usar con VS Code

1. Instala la [extensión de AngelScript](https://marketplace.visualstudio.com/items?itemName=Gaftherman.angelscript-gaftherman) y abre un archivo `.as`.
2. Añade esto a `configurations` en `.vscode/launch.json`:

~~~json
{ "type": "angelscript", "request": "launch", "name": "Run script", "program": "${file}" }
~~~

3. Pulsa F5. La extensión busca `angelscript`, `asc` o `angelscript-cli` en el PATH. Define `angelscript.runner.path` para usar otro ejecutable.

<p align="center"><img src="docs/images/vscode-files.png" alt="files.as abierto en VS Code con asc ejecutándolo en la terminal" width="720"></p>
<p align="center"><em>La extensión revisa el código mientras escribes. La terminal lo ejecuta con <code>asc</code>.</em></p>

<p align="center"><img src="docs/images/vscode-tcp-echo.png" alt="tcp-echo.as abierto en VS Code con su salida en la terminal" width="720"></p>
<p align="center"><em>Un ejemplo de eco TCP y su salida.</em></p>

## Referencia

| Comando | Hace |
| --- | --- |
| `asc script.as [args]` | Ejecuta `main()`. Los argumentos llegan al script con `getArgs()` |
| `asc --check script.as` | Solo compila |
| `asc --dap-port 9002 script.as` | Espera un depurador en el puerto 9002 y luego ejecuta |
| `asc --version`, `asc --help` | Muestra la versión o el uso |

Códigos de salida: **0** éxito o `void main()`, **1** error de compilación o de ejecución, **2** línea de comandos inválida. Un script con `int main()` aporta su propio código.

Incluido: cadenas y utilidades de cadenas, arrays, diccionarios, matemáticas, archivos, sistema de archivos, fecha y hora, utilidades de excepciones, `print`, `println`, `getArgs` y sockets TCP (`tcpConnect`, `tcpListen`).

## Compilar desde el código

Usa un compilador C++20, CMake 3.21+ y Ninja. Usa una terminal de desarrollador x64 para MSVC. Node.js habilita la prueba de DAP. Elige **windows-x64**, **linux-x64**, **linux-arm64** o **macos**.

~~~sh
git clone --recursive https://github.com/Gaftherman/angelscript-cli.git
cd angelscript-cli
cmake --preset windows-x64
cmake --build --preset windows-x64
ctest --preset windows-x64
~~~

## Hoja de ruta

[Gestión de paquetes y JIT](docs/ROADMAP.md)

## Créditos

AngelScript CLI se apoya en el trabajo de estos proyectos. Sus licencias se reproducen en [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) y se incluyen en cada paquete.

| Proyecto | Licencia | Uso |
| --- | --- | --- |
| [AngelScript](https://github.com/anjo76/angelscript) de Andreas Jönsson | zlib | El lenguaje y su runtime |
| [asdebugger](https://github.com/Gaftherman/asdebugger) | MIT | Núcleo del Debug Adapter Protocol |
| [cppdap](https://github.com/google/cppdap) | Apache-2.0 | Biblioteca del Debug Adapter Protocol |
| [nlohmann/json](https://github.com/nlohmann/json) | MIT | JSON, a través de cppdap |

## Licencia

[MIT](LICENSE)
