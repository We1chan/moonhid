import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdtemp, readFile, rm, mkdir, writeFile } from 'node:fs/promises';
import net from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const chromeBin = process.env.CHROME_BIN ?? (process.platform === 'darwin' ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : 'google-chrome');
const profile = await mkdtemp(join(tmpdir(), 'moonhid-chrome-'));
const listener = net.createServer();
listener.listen(0, '127.0.0.1');
await once(listener, 'listening');
const port = listener.address().port;
await new Promise(resolve => listener.close(resolve));
const server = spawn(process.env.PYTHON ?? 'python3', ['scripts/serve-web.py', '--port', String(port)], { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
let chrome;
let socket;
const errors = [];

try {
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Inspector server startup timed out')), 15000);
    server.stdout.on('data', () => { clearTimeout(timer); resolve(); });
    server.once('error', reject);
    server.once('exit', code => reject(new Error(`Inspector server exited: ${code}`)));
  });
  chrome = spawn(chromeBin, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run', '--no-default-browser-check', '--disable-background-networking', '--disable-component-update', ...(process.platform === 'linux' ? ['--no-sandbox'] : [])], { stdio: ['ignore', 'ignore', 'pipe'] });
  const endpoint = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Chrome startup timed out')), 15000);
    let log = '';
    chrome.stderr.on('data', bytes => {
      log += bytes;
      const match = log.match(/DevTools listening on (ws:\/\/[^\s]+)/);
      if (match) { clearTimeout(timer); resolve(match[1]); }
    });
    chrome.once('error', reject);
    chrome.once('exit', code => reject(new Error(`Chrome exited: ${code}`)));
  });
  socket = new WebSocket(endpoint);
  await once(socket, 'open');
  let nextId = 0;
  const pending = new Map();
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const { resolve, reject, timer } = pending.get(message.id);
      clearTimeout(timer); pending.delete(message.id);
      if (message.error) reject(new Error(JSON.stringify(message.error))); else resolve(message.result);
    } else if (message.method === 'Runtime.exceptionThrown') errors.push(message.params.exceptionDetails.text);
    else if (message.method === 'Runtime.consoleAPICalled' && ['error', 'warning'].includes(message.params.type)) errors.push(JSON.stringify(message.params.args));
  });
  const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
    const id = ++nextId;
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`${method} timed out`)); }, 15000);
    pending.set(id, { resolve, reject, timer });
    socket.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
  });
  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
  const call = (method, params) => send(method, params, sessionId);
  await call('Runtime.enable');
  await call('Page.enable');
  await call('Page.navigate', { url: `http://127.0.0.1:${port}/` });
  const evaluate = async expression => {
    const result = await call('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
    if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
    return result.result.value;
  };
  await evaluate(`new Promise((resolve, reject) => { const start = Date.now(); const check = () => { if (document.querySelector('[data-fixture="mouse"]')) resolve(true); else if (Date.now() - start > 10000) reject(new Error('Core loading timed out')); else setTimeout(check, 20); }; check(); })`);
  const fixtures = [...(await readFile(join(root, 'real_devices_test.mbt'), 'utf8')).matchAll(/fn real_device_([a-g])\(\) -> String \{\s*"([^"]+)"/g)];
  const setText = (id, value) => evaluate(`(() => { const node = document.getElementById(${JSON.stringify(id)}); node.value = ${JSON.stringify(value)}; node.dispatchEvent(new Event('input', { bubbles: true })); node.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', ctrlKey: true, bubbles: true })); })()`);
  const text = id => evaluate(`document.getElementById(${JSON.stringify(id)}).textContent`);
  const field = index => evaluate(`document.querySelector('#values button.field-ref') && [...document.querySelectorAll('#values button.field-ref')].find(b => b.textContent === '#${index}')?.click()`);
  for (const width of [1440, 1100, 390]) {
    await call('Emulation.setDeviceMetricsOverride', { width, height: width === 390 ? 844 : 900, deviceScaleFactor: 1, mobile: false });
    for (const [, label, descriptor] of fixtures) {
      await setText('descriptor', descriptor);
      assert.equal(await evaluate('document.getElementById("export").disabled'), false, `${label} descriptor`);
      assert.equal(await evaluate('document.documentElement.scrollWidth <= innerWidth'), true, `${label} overflow at ${width}`);
    }
    const f = fixtures.find(([, label]) => label === 'f')[2];
    await setText('descriptor', f);
    await evaluate(`[...document.querySelectorAll('#reports button')].find(b => b.querySelector('strong').textContent === 'Input' && b.textContent.includes('ID 2')).click()`);
    await setText('report', '02 ' + 'a5 '.repeat(2003).trim());
    assert.match(await text('values'), /共 2003 字节/);
    assert.match(await text('report-status'), /1 个原始字节值/);
    assert.match(await text('field-detail'), /原始字节字段，不解码为整数/);
    assert.equal(await evaluate('document.querySelectorAll("#bitmap .bm-row:not(.bm-head)").length'), 256);
    const exported = await evaluate(`(async () => {
      let blob;
      const create = URL.createObjectURL;
      const click = HTMLAnchorElement.prototype.click;
      URL.createObjectURL = value => { blob = value; return create(value); };
      HTMLAnchorElement.prototype.click = () => {};
      try { document.getElementById('export').click(); }
      finally { URL.createObjectURL = create; HTMLAnchorElement.prototype.click = click; }
      return JSON.parse(await blob.text());
    })()`);
    assert.equal(exported.schema_version, 2);
    assert.equal(exported.decoded.opaque_values[0].hex.split(' ').length, 2003);
    const b = fixtures.find(([, label]) => label === 'b')[2];
    await setText('descriptor', b);
    await evaluate(`[...document.querySelectorAll('#reports button')].find(b => b.querySelector('strong').textContent === 'Input' && b.textContent.includes('ID 68')).click()`);
    assert.equal(await evaluate('document.querySelectorAll("#values tbody tr").length'), 200);
    for (let page = 0; page < 8; page++) await evaluate(`document.querySelector('#values .pager button:last-child').click()`);
    assert.equal(await evaluate('document.querySelectorAll("#values tbody tr").length'), 151);
    const g = fixtures.find(([, label]) => label === 'g')[2];
    await setText('descriptor', g);
    await evaluate(`[...document.querySelectorAll('#reports button')].find(b => b.querySelector('strong').textContent === 'Input' && b.textContent.includes('ID 3')).click()`);
    await field(6);
    assert.match(await text('field-detail'), /0x00 … 0x7FFF（32768 个）/);
    await setText('report', '03 ff 7f');
    assert.match(await text('values'), /32767/);
    for (const theme of ['light', 'dark']) {
      await call('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: theme }] });
      assert.equal(await evaluate('document.documentElement.scrollWidth <= innerWidth'), true, `theme overflow at ${width}`);
      if (process.env.MOONHID_SCREENSHOTS) {
        await mkdir(process.env.MOONHID_SCREENSHOTS, { recursive: true });
        const { data } = await call('Page.captureScreenshot', { format: 'png' });
        await writeFile(join(process.env.MOONHID_SCREENSHOTS, `inspector-${width}-${theme}.png`), Buffer.from(data, 'base64'));
      }
    }
  }
  await setText('descriptor', '05 q1');
  assert.match(await text('descriptor-status'), /invalid_hex/);
  assert.equal(await evaluate('document.getElementById("export").disabled'), true);
  assert.deepEqual(errors, []);
  console.log('Inspector DOM: A–G, opaque bytes, 256-byte bitmap cap, large Usage, three widths, two themes and diagnostics passed.');
} finally {
  socket?.close();
  for (const child of [chrome, server]) {
    if (child && child.exitCode === null) { child.kill('SIGTERM'); await Promise.race([once(child, 'exit'), new Promise(resolve => setTimeout(resolve, 3000))]); }
  }
  await rm(profile, { recursive: true, force: true });
}
