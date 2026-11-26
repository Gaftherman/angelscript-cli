#!/usr/bin/env node
// Captures the examples of the README as screenshots: each script open in VS Code with the
// terminal below it, after `asc <script>` ran and printed its output.
//
//   node capture-examples.mjs --client <angelscript-lsp/client> --cli <angelscript.exe> \
//        --examples <angelscript-cli/examples> --out <output dir> [--modules <dir with node_modules>]
//
// The client folder must be a built extension (`npm run bundle`). playwright-core and
// @vscode/test-electron must be installed in it, or in the folder given with --modules.
// The workspace lives in a neutral folder so no personal path appears in a capture.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const option = name => {
  const index = process.argv.indexOf(`--${name}`);
  return index > 0 ? path.resolve(process.argv[index + 1]) : undefined;
};
const clientRoot = option('client');
const cliBinary = option('cli');
const examplesDir = option('examples');
const outDir = option('out') ?? path.resolve(here, '../../docs/images');
if (!clientRoot || !cliBinary || !examplesDir) {
  console.error('Usage: capture-examples.mjs --client <dir> --cli <exe> --examples <dir> [--out <dir>]');
  process.exit(2);
}

// What each capture types in the terminal and the text that proves the command finished.
const cases = [
  { name: 'hello', file: 'hello.as', commands: [
    { line: 'asc hello.as', expect: /Hello, world!/ },
    { line: 'asc hello.as Ada', expect: /Hello, Ada!/ },
  ] },
  { name: 'files', file: 'files.as', commands: [
    { line: 'asc files.as', expect: /size: 23 bytes/ },
  ] },
  { name: 'sum', file: 'sum.as', commands: [
    { line: 'asc sum.as 10 20 30', expect: /sum = 60/ },
    { line: 'echo %ERRORLEVEL%', expect: /^60\s*$/m },
  ] },
  { name: 'tcp-echo', file: 'tcp-echo.as', commands: [
    { line: 'asc tcp-echo.as', expect: /client got: echo: hello over tcp/ },
  ] },
  { name: 'strings', file: 'strings.as', commands: [
    { line: 'asc strings.as', expect: /float: 3\.14/ },
  ] },
];

const modulesRoot = option('modules') ?? clientRoot;
const require = createRequire(path.join(modulesRoot, 'package.json'));
const { _electron: electron } = require('playwright-core');
const { downloadAndUnzipVSCode } = require('@vscode/test-electron');

const workspace = 'C:\\demo\\cli';
const binDir = 'C:\\demo\\cli-bin';
for (const dir of [workspace, binDir]) fs.rmSync(dir, { recursive: true, force: true });
for (const dir of [workspace, binDir, outDir]) fs.mkdirSync(dir, { recursive: true });

fs.copyFileSync(cliBinary, path.join(binDir, 'asc.exe'));
for (const name of ['angelscript-cli.as.predefined', 'angelscript.rules.json', ...cases.map(c => c.file)]) {
  fs.copyFileSync(path.join(examplesDir, name), path.join(workspace, name));
}

// AngelLSP 1.2.4 reads `array<class T>` (what `--dump-predefined` writes) as two template
// parameters and reports E260 on every `array<string>`. The plain spelling is accepted, so the
// captures use it until the server or the dump changes.
{
  const stub = path.join(workspace, 'angelscript-cli.as.predefined');
  fs.writeFileSync(stub, fs.readFileSync(stub, 'utf8').replace(/<class T>/g, '<T>'));
}
// The extension also bundles stubs; pick the CLI's own so its `array<T>` is the one that is checked.
fs.mkdirSync(path.join(workspace, '.vscode'), { recursive: true });
fs.writeFileSync(path.join(workspace, '.vscode', 'settings.json'), JSON.stringify({
  'angelscript.predefined.active': '${workspaceFolder}/angelscript-cli.as.predefined',
}, null, 2));

const settings = JSON.parse(fs.readFileSync(path.join(clientRoot, 'scripts/demos/user-settings.json'), 'utf8'));
const userDataDir = fs.mkdtempSync(path.join(clientRoot, '.vscode-test', 'cli-user-data-'));
fs.mkdirSync(path.join(userDataDir, 'User'));
fs.writeFileSync(path.join(userDataDir, 'User', 'settings.json'), JSON.stringify({
  ...settings,
  'terminal.integrated.defaultProfile.windows': 'Command Prompt',
  'terminal.integrated.fontSize': 15,
  'terminal.integrated.gpuAcceleration': 'off',
  'editor.fontSize': 15,
  'editor.lineHeight': 20,
  'editor.padding.top': 6,
  'editor.padding.bottom': 6,
  'editor.codeLens': false,
  'editor.inlayHints.enabled': 'off',
  'editor.hover.enabled': false,
  'workbench.activityBar.location': 'hidden',
  'workbench.editor.showTabs': 'none',
  'window.title': '${activeEditorShort}${separator}${rootName}',
}, null, 2));

const vscodePath = await downloadAndUnzipVSCode('1.146.0');
const emptyExt = path.join(clientRoot, '.vscode-test', 'empty-extensions');
fs.mkdirSync(emptyExt, { recursive: true });

const app = await electron.launch({
  executablePath: vscodePath,
  env: { ...process.env, PATH: `${binDir};${process.env.PATH}`, PROMPT: '$P$G' },
  args: [
    '--window-size=1280,800', '--force-device-scale-factor=1', workspace,
    '--extensionDevelopmentPath=' + clientRoot,
    '--extensions-dir=' + emptyExt, '--user-data-dir=' + userDataDir,
    '--locale=en', '--no-sandbox', '--disable-gpu-sandbox', '--disable-updates',
    '--disable-telemetry', '--disable-workspace-trust', '--skip-welcome', '--skip-release-notes',
    path.join(workspace, cases[0].file),
  ],
});

let failure;
try {
  const win = await app.firstWindow();
  await win.waitForSelector('.monaco-workbench', { timeout: 30000 });
  try {
    const bw = await app.browserWindow(win);
    await bw.evaluate(b => { b.setContentSize(1280, 800); b.center(); });
  } catch { /* the window keeps its size */ }

  const terminalText = async () => (await win.locator('.xterm-rows').first().innerText()).replace(/\u00a0/g, ' ');
  const waitTerminal = async (pattern, timeout = 15000) => {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      if (pattern.test(await terminalText())) return;
      await win.waitForTimeout(150);
    }
    throw new Error(`The terminal never showed ${pattern}.\n${await terminalText()}`);
  };
  const palette = async command => {
    await win.keyboard.press('Control+Shift+P');
    await win.waitForTimeout(300);
    await win.keyboard.type(command);
    await win.keyboard.press('Enter');
    await win.waitForTimeout(500);
  };

  // The extension needs a moment to start the language server before the first frame is steady.
  await win.waitForTimeout(12000);
  await palette('View: Close Primary Side Bar');
  await win.keyboard.press('Control+`');
  await win.locator('.xterm-rows').first().waitFor({ timeout: 10000 });
  await waitTerminal(/>\s*$/, 10000);

  for (const item of cases) {
    // Open the script from Quick Open, then give the terminal the focus.
    await win.keyboard.press('Control+p');
    await win.waitForTimeout(300);
    await win.keyboard.type(item.file);
    await win.waitForTimeout(400);
    await win.keyboard.press('Enter');
    await win.locator('.part.editor .view-line').first().waitFor({ timeout: 8000 });
    await win.waitForTimeout(1500);
    await win.keyboard.press('Control+`');
    await win.waitForTimeout(400);
    await win.keyboard.type('cls');
    await win.keyboard.press('Enter');
    await win.waitForTimeout(500);

    for (const command of item.commands) {
      await win.keyboard.type(command.line, { delay: 40 });
      await win.keyboard.press('Enter');
      await waitTerminal(command.expect);
      await win.waitForTimeout(400);
    }
    await win.waitForTimeout(800);

    if (process.argv.includes('--debug')) {
      await palette('View: Focus Problems');
      console.log(`--- problems for ${item.name}\n` + (await win.locator('.markers-panel').first().innerText()));
      await win.keyboard.press('Control+`');
      await win.waitForTimeout(400);
    }

    const pageText = await win.evaluate(() => document.body.innerText);
    for (const secret of [os.userInfo().username, os.homedir(), os.hostname()]) {
      if (secret && pageText.toLowerCase().includes(secret.toLowerCase())) {
        throw new Error(`The page for ${item.name} contains a private value.`);
      }
    }
    await win.screenshot({ path: path.join(outDir, `example-${item.name}.png`) });
    console.log(`captured example-${item.name}.png`);
  }
} catch (error) {
  failure = error;
}

await app.close();
fs.rmSync(userDataDir, { recursive: true, force: true });
if (failure) {
  console.error(failure.message);
  process.exit(1);
}
