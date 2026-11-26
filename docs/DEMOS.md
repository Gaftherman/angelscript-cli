# Recording the captures

The example images of the README (`docs/images/example-*.png`) are produced by a script, so they can be reproduced after any change. Each shows a script open in VS Code with Command Prompt below it, after `asc <script>` ran.

## Requirements

- Node.js 20.
- A built AngelScript extension (`npm run bundle` in `angelscript-lsp/client`).
- `playwright-core` and `@vscode/test-electron` (`npm install` in any folder, passed with `--modules`).
- A build of this CLI and its `examples/` folder.

## Capture

```text
> cd angelscript-lsp\client
> node ..\..\angelscript-cli\scripts\demos\capture-examples.mjs ^
    --client . --cli ..\..\angelscript-cli\build\windows-x64\bin\angelscript.exe ^
    --examples ..\..\angelscript-cli\examples --out ..\..\angelscript-cli\docs\images ^
    --modules <folder with node_modules>
```

Run it from the client folder so VS Code is downloaded once into its `.vscode-test`. The workspace is created in `C:\demo\cli` and the prompt is `C:\demo\cli>`, so no personal path appears. The script waits for the expected output of each command (the terminal text) and stops if it is missing. It also fails if the page contains the user name, the home folder or the computer name.

`--debug` prints the Problems panel of each capture. It must say that no problems were detected.

## Review

Open every PNG before publishing it: the last line of the code must be visible, the output complete, and no red squiggle or personal path may show. An image-reading model can give a second opinion; it does not replace looking at them.
