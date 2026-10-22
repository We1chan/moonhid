import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import net from 'node:net';
import { fileURLToPath } from 'node:url';

const directory = fileURLToPath(new URL('../_build/distribution/moonhid-inspector/', import.meta.url));
const listener = net.createServer();
listener.listen(0, '127.0.0.1');
await once(listener, 'listening');
const port = listener.address().port;
await new Promise(resolve => listener.close(resolve));
const child = spawn(process.execPath, ['scripts/serve-offline.mjs'], { cwd: directory, env: { ...process.env, MOONHID_PORT: String(port) }, stdio: ['ignore', 'pipe', 'pipe'] });
try {
  await Promise.race([once(child.stdout, 'data'), once(child, 'exit').then(([code]) => { throw new Error(`Offline server exited: ${code}`); }), new Promise((_, reject) => setTimeout(() => reject(new Error('Offline server startup timed out')), 10000).unref())]);
  const base = `http://127.0.0.1:${port}`;
  for (const file of ['/', '/capture.html', '/moonhid-core.js', '/lint-ui.js', '/browser-descriptor.js', '/styles.css']) {
    const response = await fetch(base + file);
    assert.equal(response.status, 200, file);
    assert.ok((await response.text()).length > 20, file);
  }
  assert.equal((await fetch(base + '/moonhid-core.js')).headers.get('content-type'), 'text/javascript; charset=utf-8');
  assert.equal((await fetch(base + '/')).headers.get('cache-control'), 'no-store');
  assert.equal((await fetch(base + '/LICENSE')).status, 404);
  assert.equal((await fetch(base + '/%2e%2e%5cLICENSE')).status, 404);
  assert.equal((await fetch(base + '/', { method: 'POST' })).status, 405);
  assert.equal(await (await fetch(base + '/', { method: 'HEAD' })).text(), '');
  // Exercise the packaged module, so copying an old parser cannot pass on assets alone.
  const { initialize_wire, write_wire_field } = await import(new URL('../_build/distribution/moonhid-inspector/web/moonhid-core.js', import.meta.url));
  const leds = '05 08 19 01 29 05 15 00 25 01 75 01 95 05 91 02 75 03 95 01 91 01';
  assert.equal(JSON.parse(initialize_wire(leds, 'output', 0)).wire_hex, '00');
  assert.equal(JSON.parse(write_wire_field(leds, 'output', 'e0', 0, 1, '1')).wire_hex, 'e2');
  console.log('Prebuilt offline bundle: Node-only startup, assets, packaged field editor core, MIME, HEAD and path restrictions passed.');
} finally {
  if (child.exitCode === null && child.signalCode === null) {
    const exited = once(child, 'exit');
    child.kill();
    await exited;
  }
}
