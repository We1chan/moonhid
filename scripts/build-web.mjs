import { spawnSync } from 'node:child_process';
import { copyFile, mkdir, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const build = spawnSync('moon', ['build', 'src/browser', '--target', 'js', '--release'], { cwd: root, stdio: 'inherit' });
if (build.error) throw build.error;
if (build.status !== 0) process.exit(build.status ?? 1);
const directory = join(root, '_build/js/release/build/browser');
const modules = (await readdir(directory)).filter(name => name.endsWith('.js'));
if (modules.length !== 1) throw new Error(`Expected one browser module, found ${modules.join(', ')}`);
await mkdir(join(root, 'web'), { recursive: true });
await copyFile(join(directory, modules[0]), join(root, 'web/moonhid-core.js'));
console.log('Built web/moonhid-core.js from MoonBit (JS, release).');
