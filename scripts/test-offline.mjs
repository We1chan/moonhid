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
  console.log('Prebuilt offline bundle: Node-only startup, assets, MIME, HEAD and path restrictions passed.');
} finally {
  if (child.exitCode === null && child.signalCode === null) {
    const exited = once(child, 'exit');
    child.kill();
    await exited;
  }
}
