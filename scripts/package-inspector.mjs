import { mkdir, copyFile, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const destination = join(root, '_build/distribution/moonhid-inspector');
await mkdir(join(destination, 'web'), { recursive: true });
await mkdir(join(destination, 'scripts'), { recursive: true });
for (const file of ['index.html', 'capture.html', 'app.js', 'capture.js', 'browser-descriptor.js', 'hid-live.js', 'lint-ui.js', 'lesson.js', 'moonhid-core.js', 'styles.css', 'favicon.svg', 'package.json']) {
  await copyFile(join(root, 'web', file), join(destination, 'web', file));
}
await copyFile(join(root, 'scripts/serve-offline.mjs'), join(destination, 'scripts/serve-offline.mjs'));
await copyFile(join(root, 'LICENSE'), join(destination, 'LICENSE'));
const commit = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim();
await writeFile(join(destination, 'BUILD.json'), JSON.stringify({ commit, built_at: new Date().toISOString(), node: process.version }, null, 2) + '\n');
await writeFile(join(destination, 'start-inspector.cmd'), '@echo off\r\ncd /d "%~dp0"\r\nnode scripts\\serve-offline.mjs\r\npause\r\n');
await writeFile(join(destination, 'README.txt'), 'MoonHID offline inspector\n\nRequires Node.js 22+. No MoonBit, npm install, Python or network access is needed.\nRun: node scripts/serve-offline.mjs\nThen open http://127.0.0.1:8765/ in your browser.\nWindows: double-click start-inspector.cmd.\nThe optional WebHID mode still requires selecting a compatible device.\nThis bundle contains reference-layout capture, not raw descriptor extraction.\n');
console.log(destination);
