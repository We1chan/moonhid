import { spawn, spawnSync } from 'node:child_process';
import { access, mkdir, readFile, writeFile } from 'node:fs/promises';
import { delimiter, dirname, join, resolve } from 'node:path';
import { homedir, release } from 'node:os';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const exists = path => access(path).then(() => true, () => false);

async function executable(names, env) {
  for (const name of names.filter(Boolean)) {
    if (name.includes('/') || name.includes('\\')) {
      if (await exists(name)) return resolve(name);
      continue;
    }
    const suffixes = process.platform === 'win32' ? ['', '.exe', '.com'] : [''];
    for (const directory of (env.PATH ?? env.Path ?? '').split(delimiter)) {
      for (const suffix of suffixes) {
        const path = join(directory, name + suffix);
        if (await exists(path)) return path;
      }
    }
  }
  return null;
}

function probe(command, args, env) {
  if (!command) return null;
  const result = spawnSync(command, args, { cwd: root, env, encoding: 'utf8', timeout: 10000, windowsHide: true });
  return result.status === 0 ? result.stdout.trim() : null;
}

function execute(command, args, options) {
  return new Promise(resolveResult => {
    let output = '';
    const child = spawn(command, args, { ...options, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');
    child.stdout.on('data', text => { output += text; });
    child.stderr.on('data', text => { output += text; });
    child.once('error', error => resolveResult({ code: null, output: output + error.message }));
    child.once('close', (code, signal) => resolveResult({ code, signal, output }));
  });
}

// Exported for process-level contract tests; commands are always passed as argv,
// without a shell, including paths/arguments containing spaces on Windows.
export async function runSteps(steps, { cwd = root, env = process.env, logDirectory, progress = () => {} }) {
  await mkdir(logDirectory, { recursive: true });
  const results = [];
  for (const [index, step] of steps.entries()) {
    const { id, name, command, args = [], required = true, needs = [], skipReason } = step;
    const blocked = needs.filter(id => results.find(result => result.id === id)?.status !== 'PASS');
    const reason = skipReason || (blocked.length ? `前置步骤未通过：${blocked.join(', ')}` : null);
    if (reason) {
      results.push({ id, name, required, status: 'SKIP', duration_ms: 0, reason });
      progress(results.at(-1));
      continue;
    }
    const start = performance.now();
    const result = await execute(command, args, { cwd, env });
    const log = join(logDirectory, `${String(index + 1).padStart(2, '0')}-${id}.log`);
    await writeFile(log, result.output);
    results.push({ id, name, required, status: result.code === 0 ? 'PASS' : 'FAIL',
      duration_ms: Math.round(performance.now() - start), command: [command, ...args],
      exit_code: result.code, signal: result.signal ?? null, log,
      output_tail: result.output.slice(-3000) });
    progress(results.at(-1));
  }
  return results;
}

export const acceptanceFailed = results => results.some(result => result.status === 'FAIL' || (result.required && result.status !== 'PASS'));

async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help')) {
    console.log('用法：node scripts/acceptance.mjs [--quick]\n默认检查四后端；--quick 仅检查 wasm/js，并跳过 native CLI 与需要 native 的 hid-tools 编码对照。\n可选环境变量：MOON_BIN、MOON_HOME、PYTHON、CHROME_BIN。报告：_build/acceptance-report.json');
    return;
  }
  if (args.some(arg => arg !== '--quick')) throw new Error('仅支持 --quick 或 --help');
  const quick = args.includes('--quick');
  const env = { ...process.env };
  const moon = await executable([env.MOON_BIN, 'moon', join(env.MOON_HOME ?? join(homedir(), '.moon'), 'bin', process.platform === 'win32' ? 'moon.exe' : 'moon')], env);
  if (moon) {
    env.PATH = dirname(moon) + delimiter + (env.PATH ?? env.Path ?? '');
    if (process.platform === 'win32') delete env.Path;
  }
  const python = await executable([env.PYTHON, ...(process.platform === 'win32' ? ['python', 'python3'] : ['python3', 'python'])], env);
  const pythonVersion = probe(python, ['-c', 'import sys; print(sys.version.split()[0])'], env);
  if (pythonVersion) env.PYTHON = python;
  const hidTools = pythonVersion ? probe(python, ['-c', 'from importlib.metadata import version; print(version("hid-tools"))'], env) : null;
  const chrome = await executable([env.CHROME_BIN,
    ...(process.platform === 'win32' ? [
      join(env.ProgramFiles ?? 'C:/Program Files', 'Google/Chrome/Application/chrome.exe'),
      join(env['ProgramFiles(x86)'] ?? 'C:/Program Files (x86)', 'Google/Chrome/Application/chrome.exe'),
      ...(env.LOCALAPPDATA ? [join(env.LOCALAPPDATA, 'Google/Chrome/Application/chrome.exe')] : []),
    ] : process.platform === 'darwin' ? ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'] : ['google-chrome', 'chromium', 'chromium-browser']),
  ], env);
  if (chrome) env.CHROME_BIN = chrome;
  const expected = JSON.parse(await readFile(join(root, 'toolchain.json'), 'utf8'));
  const nodeStep = (id, name, file, args = [], extra = {}) => ({ id, name, command: process.execPath, args: [`scripts/${file}`, ...args], ...extra });
  const moonStep = (id, name, args, extra = {}) => ({ id, name, command: moon ?? 'moon', args, needs: ['toolchain'], ...extra });
  const optionalNative = quick ? '--quick 仅检查 wasm/js；完整运行请去掉 --quick。' : null;
  const optionalHid = hidTools === expected.hid_tools ? null : `需要 Python 与 hid-tools ${expected.hid_tools}；设置 PYTHON 后执行 python -m pip install hid-tools==${expected.hid_tools}。`;
  const checks = quick ? [
    moonStep('check-wasm', '无警告检查 wasm', ['check', '--target', 'wasm', '--deny-warn']),
    moonStep('check-js', '无警告检查 js', ['check', '--target', 'js', '--deny-warn']),
  ] : [moonStep('check', '四后端无警告检查', ['check', '--target', 'all', '--deny-warn'])];
  const tests = quick ? [
    moonStep('test-wasm', '测试 wasm', ['test', '--target', 'wasm']),
    moonStep('test-js', '测试 js', ['test', '--target', 'js']),
  ] : [moonStep('test-all', '四后端测试', ['test', '--target', 'all'])];
  const steps = [
    { id: 'node', name: 'Node 版本', command: process.execPath, args: ['-e', 'if(Number(process.versions.node.split(".")[0])<22)process.exit(1);console.log(process.version)'] },
    { id: 'toolchain', name: 'MoonBit 工具链', command: moon ?? 'moon', args: ['version', '--all'] },
    nodeStep('readme', 'README 与文档链接', 'sync-readme.mjs', ['--check']),
    nodeStep('facts', '文档事实确认', 'check-acceptance-docs.mjs'),
    nodeStep('public-docs-test', '公开链接检查器反例', 'test-public-docs.mjs'),
    ...checks,
    ...tests,
    moonStep('scenarios-wasm', '四场景演示 wasm', ['run', 'src/cmd/scenarios', '--target', 'wasm']),
    moonStep('scenarios-js', '四场景演示 js', ['run', 'src/cmd/scenarios', '--target', 'js']),
    nodeStep('web-build', '构建网页核心', 'build-web.mjs', [], { needs: ['toolchain'] }),
    nodeStep('web', '浏览器桥接', 'test-web.mjs', [], { needs: ['web-build'] }),
    nodeStep('webhid', 'WebHID 模拟', 'test-webhid.mjs', [], { needs: ['web-build'] }),
    nodeStep('usability', '教学与 Xbox 回放', 'test-usability.mjs', [], { needs: ['web-build'] }),
    nodeStep('cli-js', '文件 CLI js', 'test-cli.mjs', ['js'], { needs: ['toolchain'] }),
    nodeStep('compat-js', '标准报告案例 js', 'test-compatibility.mjs', ['js'], { needs: ['toolchain'] }),
    nodeStep('firmware', '固件 CI js', 'firmware-ci.mjs', ['js'], { needs: ['toolchain'] }),
    nodeStep('package', '打包离线检查器', 'package-inspector.mjs', [], { needs: ['web-build'] }),
    nodeStep('offline', '离线包与服务', 'test-offline.mjs', [], { needs: ['package'] }),
    nodeStep('cli-native', '文件 CLI native', 'test-cli.mjs', ['native'], { required: false, skipReason: optionalNative, needs: quick ? [] : ['test-all'] }),
    nodeStep('compat-native', '标准报告案例 native', 'test-compatibility.mjs', ['native'], { required: false, skipReason: optionalNative, needs: quick ? [] : ['test-all'] }),
    { id: 'hid-layout', name: 'hid-tools 布局对照', command: python, args: ['scripts/compare-hid-tools.py'], required: false, skipReason: optionalHid, needs: ['web-build'] },
    { id: 'hid-codec', name: 'hid-tools 编码对照', command: python, args: ['scripts/compare-codec-hid-tools.py'], required: false, skipReason: optionalNative ?? optionalHid, needs: quick ? [] : ['test-all'] },
    nodeStep('inspector', 'Chrome 界面交互', 'test-inspector.mjs', [], { required: false, needs: ['web-build'], skipReason: !chrome || !pythonVersion ? '需要 Chrome 和 Python 3；设置 CHROME_BIN 与 PYTHON 后重试。' : null }),
  ];
  console.log(`MoonHID ${quick ? '快速验收（wasm/js）' : '完整验收（四后端）'}，逐步日志保存在 _build/acceptance-logs。`);
  const results = await runSteps(steps, { cwd: root, env, logDirectory: join(root, '_build/acceptance-logs'), progress: result => {
    console.log(`${result.status.padEnd(4)} ${result.name} (${(result.duration_ms / 1000).toFixed(2)}s)`);
    if (result.reason) console.log('     ' + result.reason);
    if (result.status === 'FAIL') console.error(result.output_tail);
  } });
  const report = {
    schema_version: 1, generated_at: new Date().toISOString(), mode: quick ? 'quick' : 'full',
    commit: probe('git', ['rev-parse', 'HEAD'], env), dirty: Boolean(probe('git', ['status', '--porcelain'], env)),
    platform: { os: process.platform, arch: process.arch, release: release() },
    toolchain: { expected, actual: { node: process.version, moon: results.find(result => result.id === 'toolchain')?.output_tail ?? null, python: pythonVersion, hid_tools: hidTools, chrome } },
    summary: Object.fromEntries(['PASS', 'FAIL', 'SKIP'].map(status => [status, results.filter(result => result.status === status).length])),
    success: !acceptanceFailed(results), steps: results,
  };
  await writeFile(join(root, '_build/acceptance-report.json'), JSON.stringify(report, null, 2) + '\n');
  console.table(results.map(result => ({ 步骤: result.name, 结果: result.status, 秒: (result.duration_ms / 1000).toFixed(2), 必需: result.required ? '是' : '否' })));
  console.log(`汇总：PASS ${report.summary.PASS} / FAIL ${report.summary.FAIL} / SKIP ${report.summary.SKIP}`);
  console.log('报告：_build/acceptance-report.json');
  if (!report.success) process.exitCode = 1;
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  await main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
