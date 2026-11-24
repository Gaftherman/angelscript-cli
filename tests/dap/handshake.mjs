import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { readFileSync } from 'node:fs';
import { createConnection, createServer } from 'node:net';
import { basename, normalize, resolve } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

const host = '127.0.0.1';
const cwd = fileURLToPath(new URL('../../', import.meta.url));
const source = fileURLToPath(new URL('../fixtures/debug.as', import.meta.url));
const lines = readFileSync(source, 'utf8').split(/\r?\n/);
const breakpointLine = lines.findIndex(line => line.endsWith('// BP')) + 1;
assert.ok(breakpointLine > 0, 'Missing // BP marker in debug.as');

async function freePort() {
    const server = createServer().listen(0, host);
    await once(server, 'listening');
    const { port } = server.address();
    const closed = once(server, 'close');
    server.close();
    await closed;
    return port;
}

async function connect(port, child) {
    for (let attempt = 0; attempt < 100; ++attempt) {
        assert.equal(child.exitCode, null, 'CLI exited before accepting DAP connections');
        assert.equal(child.signalCode, null, 'CLI was terminated before accepting DAP connections');

        const socket = createConnection({ host, port });
        try {
            await once(socket, 'connect');
            return socket;
        } catch (error) {
            socket.destroy();
            if (error.code !== 'ECONNREFUSED') throw error;
            await delay(50);
        }
    }
    throw new Error(`Timed out connecting to ${host}:${port}`);
}

async function* readMessages(socket) {
    let buffer = Buffer.alloc(0);
    for await (const chunk of socket) {
        buffer = Buffer.concat([buffer, chunk]);
        let headerEnd;
        while ((headerEnd = buffer.indexOf('\r\n\r\n')) !== -1) {
            const header = buffer.subarray(0, headerEnd).toString('ascii');
            const length = Number(/^Content-Length:[ \t]*(\d+)[ \t]*$/im.exec(header)?.[1]);
            assert.ok(length > 0 && length <= 16 * 1024 * 1024, 'Invalid DAP Content-Length');

            const bodyStart = headerEnd + 4;
            const bodyEnd = bodyStart + length;
            if (buffer.length < bodyEnd) break;
            const message = JSON.parse(buffer.subarray(bodyStart, bodyEnd).toString('utf8'));
            buffer = buffer.subarray(bodyEnd);
            yield message;
        }
    }
}

class DapClient {
    constructor(socket) {
        this.socket = socket;
        this.messages = readMessages(socket);
        this.events = [];
        this.seq = 0;
    }

    async receive() {
        const { done, value } = await this.messages.next();
        assert.ok(!done, 'DAP connection closed before the expected message');
        return value;
    }

    async request(command, args = {}) {
        const seq = ++this.seq;
        const body = Buffer.from(JSON.stringify({ seq, type: 'request', command, arguments: args }));
        const header = Buffer.from(`Content-Length: ${body.length}\r\n\r\n`);
        this.socket.write(Buffer.concat([header, body]));

        for (;;) {
            const message = await this.receive();
            if (message.type === 'response') {
                assert.equal(message.request_seq, seq);
                assert.equal(message.command, command);
                assert.ok(message.success, `${command} failed: ${message.message ?? 'unknown error'}`);
                return message.body;
            }
            this.events.push(message);
        }
    }

    async event(name) {
        const index = this.events.findIndex(message => message.event === name);
        if (index !== -1) return this.events.splice(index, 1)[0].body;
        for (;;) {
            const message = await this.receive();
            if (message.event === name) return message.body;
            this.events.push(message);
        }
    }
}

async function verifyHandshake(client, request, port) {
    const capabilities = await client.request('initialize', {
        clientID: 'vscode', adapterID: 'angelscript', pathFormat: 'path',
        linesStartAt1: true, columnsStartAt1: true,
    });
    assert.equal(capabilities.supportsConfigurationDoneRequest, true);
    await client.event('initialized');

    const configuration = { type: 'angelscript', request, host, port };
    if (request === 'launch') Object.assign(configuration, { program: source, args: [], cwd });
    await client.request(request, configuration);

    const { breakpoints } = await client.request('setBreakpoints', {
        source: { name: basename(source), path: source },
        lines: [breakpointLine],
        breakpoints: [{ line: breakpointLine }],
        sourceModified: false,
    });
    assert.equal(breakpoints.length, 1);
    assert.equal(breakpoints[0].verified, true);
    assert.equal(breakpoints[0].line, breakpointLine);
    await client.request('configurationDone');

    const { reason, threadId } = await client.event('stopped');
    assert.equal(reason, 'breakpoint');
    assert.ok(threadId > 0);
    const { stackFrames } = await client.request('stackTrace', { threadId });
    const frame = stackFrames[0];
    assert.ok(frame?.source?.path, 'Missing top frame source');
    assert.equal(normalize(frame.source.path), normalize(source));
    assert.equal(frame.line, breakpointLine);
    assert.match(frame.name, /\binitialValue\(/);

    const { scopes } = await client.request('scopes', { frameId: frame.id });
    const locals = scopes.find(scope => scope.presentationHint === 'locals');
    assert.ok(locals?.variablesReference > 0, 'Missing locals scope');
    const { variables } = await client.request('variables', { variablesReference: locals.variablesReference });
    assert.equal(variables.find(variable => variable.name === 'initial')?.value, '6');
    await client.request('continue', { threadId });
}

async function run(executable, request) {
    const port = await freePort();
    const child = spawn(executable, ['--dap-port', String(port), '--dap-host', host, 'tests/fixtures/debug.as'], {
        cwd, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true,
    });

    let stdout = '';
    let stderr = '';
    child.stdout.setEncoding('utf8').on('data', chunk => { stdout += chunk; });
    child.stderr.setEncoding('utf8').on('data', chunk => { stderr += chunk; });
    const finished = new Promise(resolveClose => {
        child.once('close', (code, signal) => resolveClose({ code, signal }));
    });

    let socket;
    let timedOut = false;
    const timeout = setTimeout(() => {
        timedOut = true;
        socket?.destroy();
        child.kill();
    }, 15_000);

    try {
        await once(child, 'spawn');
        socket = await connect(port, child);
        await verifyHandshake(new DapClient(socket), request, port);
        assert.deepEqual(await finished, { code: 0, signal: null });
        assert.equal(timedOut, false);
        assert.deepEqual(stdout.trimEnd().split(/\r?\n/), [
            `DAP listening on ${host}:${port}`,
            'initial value: 6',
            'total: 12',
        ]);
        assert.equal(stderr, '');
    } catch (error) {
        const detail = timedOut ? 'handshake timed out' : error.message;
        throw new Error(`DAP ${request} failed: ${detail}\nstdout: ${stdout}\nstderr: ${stderr}`, { cause: error });
    } finally {
        clearTimeout(timeout);
        socket?.destroy();
        if (child.exitCode === null && child.signalCode === null && child.pid !== undefined) child.kill();
        await finished;
    }
}

assert.ok(process.argv[2], 'Usage: node handshake.mjs <angelscript-cli>');
const executable = resolve(process.argv[2]);
await run(executable, 'launch');
await run(executable, 'attach');
