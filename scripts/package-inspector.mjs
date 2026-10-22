import { mkdir, copyFile, writeFile, readFile } from 'node:fs/promises';
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
const metadata = await readFile(join(root, 'moon.mod'), 'utf8');
const version = metadata.match(/^version\s*=\s*"([^"]+)"/m)?.[1];
await writeFile(join(destination, 'BUILD.json'), JSON.stringify({ version, commit, built_at: new Date().toISOString(), node: process.version }, null, 2) + '\n');
await writeFile(join(destination, 'start-inspector.cmd'), '@echo off\r\ncd /d "%~dp0"\r\nnode scripts\\serve-offline.mjs\r\npause\r\n');
await writeFile(join(destination, 'README.txt'), `MoonHID ${version} 离线检查器\n\n需要 Node.js 22+。直接运行，无需安装其他依赖。\n运行：node scripts/serve-offline.mjs\n浏览器打开：http://127.0.0.1:8765/\nWindows：双击 start-inspector.cmd。\n可离线解析描述符、解码报告、编辑字段并导出 HEX。\n可选 WebHID Input 需要用户选择兼容设备；浏览器采集仅能重建参考布局。\nBUILD.json 记录版本和构建提交。\n`);
console.log(destination);
