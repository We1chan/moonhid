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

async function stopProcess(child, ownGroup = false) {
  if (!child?.pid) return;
  const exited = child.exitCode !== null || child.signalCode !== null;
  const done = exited ? Promise.resolve(true) : once(child, 'exit').then(() => true);
  const signal = name => {
    try {
      if (ownGroup) process.kill(-child.pid, name);
      else child.kill(name);
    } catch (error) { if (error.code !== 'ESRCH') throw error; }
  };
  const wait = async () => {
    let timer;
    try { return await Promise.race([done, new Promise(resolve => { timer = setTimeout(() => resolve(false), 3000); })]); }
    finally { clearTimeout(timer); }
  };
  signal('SIGTERM');
  if (!await wait()) {
    signal('SIGKILL');
    if (!await wait()) throw new Error(`Test process did not exit: ${child.pid}`);
  }
}

try {
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Inspector server startup timed out')), 15000);
    server.stdout.on('data', () => { clearTimeout(timer); resolve(); });
    server.once('error', reject);
    server.once('exit', code => reject(new Error(`Inspector server exited: ${code}`)));
  });
  chrome = spawn(chromeBin, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run', '--no-default-browser-check', '--disable-background-networking', '--disable-component-update', ...(process.platform === 'linux' ? ['--no-sandbox'] : [])], { detached: process.platform !== 'win32', stdio: ['ignore', 'ignore', 'pipe'] });
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
  // Edit and click export in the same browser task, before either debounce fires.
  const exportAfterInput = (id, value) => evaluate(`(async () => {
    const editor = document.getElementById(${JSON.stringify(id)});
    editor.value = ${JSON.stringify(value)};
    editor.dispatchEvent(new Event('input', { bubbles: true }));
    const enabled = !document.getElementById('export').disabled;
    let blob;
    const create = URL.createObjectURL;
    const click = HTMLAnchorElement.prototype.click;
    URL.createObjectURL = value => { blob = value; return create(value); };
    HTMLAnchorElement.prototype.click = () => {};
    try { document.getElementById('export').click(); }
    finally { URL.createObjectURL = create; HTMLAnchorElement.prototype.click = click; }
    return { enabled, data: blob ? JSON.parse(await blob.text()) : null };
  })()`);
  const editedReport = await exportAfterInput('report', '00 00 00 00');
  assert.equal(editedReport.enabled, true);
  assert.equal(editedReport.data.wire_hex, '00 00 00 00');
  assert.ok(editedReport.data.decoded.values.every(value => value.value === 0));
  const invalidReport = await exportAfterInput('report', '00 zz');
  assert.equal(invalidReport.data.wire_hex, null);
  assert.equal(invalidReport.data.decoded, null);
  const editedDescriptor = await exportAfterInput('descriptor', '05 q1');
  assert.deepEqual(editedDescriptor, { enabled: false, data: null });
  assert.equal(await evaluate('document.querySelectorAll("#values tbody tr").length'), 0);
  await evaluate(`document.querySelector('[data-fixture="mouse"]').click()`);
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
  // Successful compilation with a Warning remains usable and can be located.
  await evaluate(`document.querySelector('.lesson-panel').open = true; document.getElementById('lesson-before').click()`);
  assert.match(await text('descriptor-status'), /已解析.*1 条需核对/);
  assert.match(await text('lints'), /没有为 Null 状态留出取值/);
  if (process.env.MOONHID_SCREENSHOTS) {
    for (const width of [1440, 390]) {
      await call('Emulation.setDeviceMetricsOverride', { width, height: 900, deviceScaleFactor: 1, mobile: false });
      assert.equal(await evaluate('document.documentElement.scrollWidth <= innerWidth'), true);
      const { data } = await call('Page.captureScreenshot', { format: 'png' });
      await writeFile(join(process.env.MOONHID_SCREENSHOTS, `lint-lesson-${width}.png`), Buffer.from(data, 'base64'));
    }
  }
  await evaluate(`document.querySelector('[data-lint-code="null_without_room"] .lint-location button').click()`);
  assert.match(await text('field-detail'), /Null State/);
  await evaluate(`document.getElementById('lesson-after').click()`);
  assert.match(await text('lints'), /当前规则未产生提示/);
  assert.match(await text('values'), /Null/);
  const repeated = '05 01 09 05 a1 01 15 00 25 01 75 08 95 01 ' + '81 02 '.repeat(80) + 'c0';
  await setText('descriptor', repeated);
  assert.equal(await evaluate('document.querySelectorAll(".lint-entry").length'), 50);
  await evaluate(`document.querySelector('#lints .pager button:last-child').click()`);
  assert.equal(await evaluate('document.querySelectorAll(".lint-entry").length'), 30);
  await evaluate(`document.querySelector('#lints .lint-entry:last-child .lint-location button').click()`);
  assert.match(await text('field-detail'), /#79/);
  await evaluate(`document.querySelector('[data-lint-filter="info"]').click()`);
  assert.match(await text('lints'), /当前筛选没有提示/);
  await setText('descriptor', '05 01 a1 01 15 00 25 01 75 08 95 01 09 30 81 02 c0');
  await evaluate(`document.querySelector('[data-lint-filter="all"]').click(); document.querySelector('[data-lint-code="collection_without_usage"] .lint-location button').click()`);
  assert.equal(await evaluate('document.querySelector("#items .focus").dataset.item'), '1');
  await setText('descriptor', '05 q1');
  assert.match(await text('descriptor-status'), /invalid_hex/);
  assert.equal(await evaluate('document.getElementById("export").disabled'), true);
  assert.match(await text('lints'), /修正编译错误/);
  // A separate page uses a simulated device. This never requests real HID access.
  await call('Page.addScriptToEvaluateOnNewDocument', { source: `
    const item = { reportSize: 8, reportCount: 1, isConstant: false, isArray: false,
      isAbsolute: false, isLinear: true, hasPreferredState: true, hasNull: false,
      isVolatile: false, isBufferedBytes: false, wrap: false, isRange: false,
      usages: [0x10030], logicalMinimum: -127, logicalMaximum: 127 };
    const device = new EventTarget();
    Object.assign(device, { opened: false, productName: '模拟 HID',
      vendorId: 123, productId: 456,
      collections: [{ usagePage: 1, usage: 5, type: 1, inputReports: [{ reportId: 3, items: [item] }], children: [] }],
      open: async () => { device.opened = true; }, close: async () => { device.opened = false; },
      emit: () => device.dispatchEvent(Object.assign(new Event('inputreport'), {
        device, reportId: 3, data: new DataView(new Uint8Array([99, 255, 88]).buffer, 1, 1)
      })) });
    const hid = new EventTarget();
    hid.requestDevice = async () => [device];
    window.__mockDevice = device; window.__mockHID = hid;
    Object.defineProperty(navigator, 'hid', { configurable: true, value: hid });
  ` });
  await call('Page.navigate', { url: `http://127.0.0.1:${port}/` });
  await evaluate(`new Promise((resolve, reject) => { const start = Date.now(); const check = () => { if (window.__mockDevice && document.querySelector('[data-fixture="mouse"]')) resolve(true); else if (Date.now() - start > 10000) reject(new Error('Mock page loading timed out')); else setTimeout(check, 20); }; check(); })`);
  await setText('descriptor', '05 01 09 30 15 81 25 7f 75 08 95 01 85 03 81 06');
  assert.equal(await evaluate('document.getElementById("hid-connect").disabled'), false);
  await evaluate(`document.getElementById('hid-connect').click(); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.match(await text('hid-status'), /模拟 HID/);
  assert.match(await text('hid-diff'), /0 项差异/);
  await evaluate(`window.__mockDevice.emit(); new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))`);
  assert.equal(await evaluate('document.getElementById("report").value'), '03 ff');
  assert.match(await text('values'), /-1/);
  await evaluate(`document.getElementById('hid-disconnect').click(); new Promise(resolve => setTimeout(resolve, 0))`);
  await setText('report', '03 00');
  await evaluate(`window.__mockDevice.emit(); new Promise(resolve => requestAnimationFrame(resolve))`);
  assert.equal(await evaluate('document.getElementById("report").value'), '03 00');
  await evaluate(`document.getElementById('hid-connect').click(); new Promise(resolve => setTimeout(resolve, 0))`);
  await evaluate(`window.__mockDevice.close = async () => { await new Promise(resolve => { window.__finishClose = resolve; }); window.__mockDevice.opened = false; }; document.getElementById('hid-disconnect').click(); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.match(await text('hid-status'), /正在断开/);
  assert.equal(await evaluate('document.getElementById("hid-connect").disabled'), true);
  assert.equal(await evaluate('document.getElementById("hid-disconnect").disabled'), true);
  await evaluate(`document.getElementById('hid-connect').click(); window.__mockDevice.emit(); new Promise(resolve => requestAnimationFrame(resolve))`);
  assert.equal(await evaluate('document.getElementById("report").value'), '03 00');
  await evaluate(`window.__finishClose(); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.match(await text('hid-status'), /已断开/);
  assert.equal(await evaluate('document.getElementById("hid-connect").disabled'), false);
  assert.equal(await evaluate('window.__mockDevice.opened'), false);
  await evaluate(`window.__mockDevice.close = async () => { window.__mockDevice.opened = false; }; document.getElementById('hid-connect').click(); new Promise(resolve => setTimeout(resolve, 0))`);
  await evaluate(`window.dispatchEvent(new PageTransitionEvent('pagehide', { persisted: true })); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.equal(await evaluate('window.__mockDevice.opened'), false);
  await evaluate(`window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true })); document.getElementById('hid-connect').click(); new Promise(resolve => setTimeout(resolve, 0))`);
  await evaluate(`window.__mockDevice.opened = false; window.__mockHID.dispatchEvent(Object.assign(new Event('disconnect'), { device: window.__mockDevice }));`);
  assert.match(await text('hid-status'), /设备已拔出/);
  await call('Page.navigate', { url: `http://127.0.0.1:${port}/capture.html` });
  await evaluate(`new Promise((resolve, reject) => { const start = Date.now(); const check = () => { if (document.querySelector('#capture-status')?.textContent.includes('请选择手柄') && window.__mockDevice) resolve(true); else if (Date.now() - start > 10000) reject(new Error('Capture page loading timed out')); else setTimeout(check, 20); }; check(); })`);
  await evaluate(`window.__mockDevice.collections[0].inputReports[0].items[0].logicalMaximum = -128; document.getElementById('capture-connect').click(); new Promise(resolve => setTimeout(resolve, 100))`);
  assert.match(await text('capture-status'), /逻辑范围不完整/);
  await evaluate(`document.getElementById('capture-raw').checked = true; document.getElementById('capture-model').value = '模拟回归设备'; document.getElementById('capture-connect').click(); new Promise(resolve => setTimeout(resolve, 100))`);
  assert.match(await text('capture-status'), /原始数值/);
  assert.equal(await evaluate('document.getElementById("capture-raw").disabled'), true);
  await evaluate(`for (let i = 0; i < 105; i++) window.__mockDevice.emit(); document.getElementById('capture-stop').click(); new Promise(resolve => setTimeout(resolve, 0))`);
  const capture = JSON.parse(await evaluate('document.getElementById("capture-record").value'));
  assert.equal(capture.raw_values_mode, true);
  assert.equal(capture.device.declared_model, '模拟回归设备');
  assert.equal(capture.total_received, 105);
  assert.equal(capture.reports.length, 100);
  assert.equal(capture.reports[0].sequence, 6);
  assert.equal(capture.reports.at(-1).wire_hex, '03 ff');
  assert.equal(capture.reports.at(-1).result.decoded.values[0].value, -1);
  assert.equal(capture.browser_collections[0].inputReports[0].items[0].logicalMaximum, -128);
  assert.equal(await evaluate('document.getElementById("capture-raw").disabled'), false);
  await evaluate(`window.__mockDevice.close = async () => { throw new Error('simulated close failure'); }; document.getElementById('capture-connect').click(); new Promise(resolve => setTimeout(resolve, 0))`);
  await evaluate(`window.__mockDevice.emit(); document.getElementById('capture-stop').click(); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.match(await text('capture-status'), /关闭失败.*simulated close failure/);
  for (const id of ['capture-connect', 'capture-raw', 'capture-model', 'capture-export']) {
    assert.equal(await evaluate(`document.getElementById(${JSON.stringify(id)}).disabled`), false, id);
  }
  assert.equal(await evaluate('document.getElementById("capture-stop").disabled'), true);
  const savedCapture = JSON.parse(await evaluate('document.getElementById("capture-record").value'));
  assert.equal(savedCapture.total_received, 1);
  assert.equal(savedCapture.reports[0].wire_hex, '03 ff');
  const exportedCapture = await evaluate(`(async () => {
    let blob;
    const create = URL.createObjectURL;
    const click = HTMLAnchorElement.prototype.click;
    URL.createObjectURL = value => { blob = value; return create(value); };
    HTMLAnchorElement.prototype.click = () => {};
    try { document.getElementById('capture-export').click(); }
    finally { URL.createObjectURL = create; HTMLAnchorElement.prototype.click = click; }
    return JSON.parse(await blob.text());
  })()`);
  assert.deepEqual(exportedCapture, savedCapture);
  await evaluate(`window.__mockDevice.emit(); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.equal(await evaluate('document.getElementById("capture-record").value'), JSON.stringify(savedCapture, null, 2));
  await evaluate(`window.__mockDevice.close = async () => { window.__mockDevice.opened = false; }; document.getElementById('capture-connect').click(); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.match(await text('capture-status'), /已连接/);
  await evaluate(`window.__mockDevice.emit(); document.getElementById('capture-stop').click(); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.match(await text('capture-status'), /已停止接收/);
  assert.equal(JSON.parse(await evaluate('document.getElementById("capture-record").value')).total_received, 1);
  const retainedCapture = await evaluate('document.getElementById("capture-record").value');
  // Leaving while open() is pending must close the late result and keep the record.
  await evaluate(`window.__mockDevice.open = async () => { window.__openingStarted = true; await new Promise(resolve => { window.__finishOpen = resolve; }); window.__mockDevice.opened = true; }; document.getElementById('capture-connect').click(); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.equal(await evaluate('window.__openingStarted'), true);
  await evaluate(`window.dispatchEvent(new PageTransitionEvent('pagehide', { persisted: true })); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.equal(await evaluate('document.getElementById("capture-connect").disabled'), true);
  await evaluate(`window.__finishOpen(); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.equal(await evaluate('window.__mockDevice.opened'), false);
  assert.equal(await evaluate('document.getElementById("capture-stop").disabled'), true);
  assert.equal(await evaluate('document.getElementById("capture-record").value'), retainedCapture);
  await evaluate(`window.__mockDevice.emit(); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.equal(await evaluate('document.getElementById("capture-record").value'), retainedCapture);
  // A pending device chooser must not open its result after leaving either.
  await evaluate(`window.__openCalls = 0; window.__mockDevice.open = async () => { window.__openCalls++; window.__mockDevice.opened = true; }; window.__mockHID.requestDevice = () => new Promise(resolve => { window.__finishChoice = resolve; }); window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true })); document.getElementById('capture-connect').click(); new Promise(resolve => setTimeout(resolve, 0))`);
  await evaluate(`window.dispatchEvent(new PageTransitionEvent('pagehide', { persisted: true })); window.__finishChoice([window.__mockDevice]); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.equal(await evaluate('window.__openCalls'), 0);
  assert.equal(await evaluate('window.__mockDevice.opened'), false);
  assert.equal(await evaluate('document.getElementById("capture-record").value'), retainedCapture);
  await evaluate(`window.__mockHID.requestDevice = async () => [window.__mockDevice]; window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true })); document.getElementById('capture-connect').click(); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.match(await text('capture-status'), /已连接/);
  await evaluate(`window.__mockDevice.emit(); window.__mockDevice.opened = false; window.__mockHID.dispatchEvent(Object.assign(new Event('disconnect'), { device: window.__mockDevice })); new Promise(resolve => setTimeout(resolve, 0))`);
  assert.match(await text('capture-status'), /已断开/);
  assert.equal(JSON.parse(await evaluate('document.getElementById("capture-record").value')).total_received, 1);
  if (process.env.MOONHID_SCREENSHOTS) {
    const { data } = await call('Page.captureScreenshot', { format: 'png' });
    await writeFile(join(process.env.MOONHID_SCREENSHOTS, 'capture.png'), Buffer.from(data, 'base64'));
  }
  assert.deepEqual(errors, []);
  console.log('Inspector DOM: A–G, widths/themes, current exports, slow disconnect, capture recovery, cancelled chooser/open and restored-page unplug passed.');
} finally {
  socket?.close();
  // The isolated Chrome process group includes its profile-writing children.
  // A bounded retry also covers the final filesystem writes during shutdown.
  await stopProcess(chrome, process.platform !== 'win32');
  await stopProcess(server);
  await rm(profile, { recursive: true, force: true, maxRetries: 10, retryDelay: 100 });
}
