import assert from 'node:assert/strict';
import { spawnSync, execFileSync } from 'node:child_process';
import { mkdtemp, readFile, writeFile, lstat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

// Always create a fresh project outside the checkout; never add a path override.
const root = fileURLToPath(new URL('../', import.meta.url));
const metadata = await readFile(join(root, 'moon.mod'), 'utf8');
const setting = name => metadata.match(new RegExp(`^${name}\\s*=\\s*"([^"]+)"`, 'm'))?.[1];
const moduleName = setting('name'), version = setting('version');
assert.ok(moduleName && version);
let ref = `v${version}`, reportPath = join(root, `docs/registry-${version}-validation.json`);
for (let i = 2; i < process.argv.length; i += 2) {
  assert.ok(process.argv[i + 1] && ['--ref', '--report'].includes(process.argv[i]), 'Usage: node scripts/verify-registry.mjs [--ref git-ref] [--report file]');
  if (process.argv[i] === '--ref') ref = process.argv[i + 1];
  else reportPath = resolve(process.argv[i + 1]);
}
const git = args => execFileSync('git', args, { cwd: root, maxBuffer: 16 * 1024 * 1024 });
const commit = git(['rev-parse', '--verify', `${ref}^{commit}`]).toString().trim();
const directory = await mkdtemp(join(tmpdir(), `moonhid-registry-${version}-`));
assert.ok(!resolve(directory).startsWith(resolve(root)), 'Registry project must be outside repository.');
await writeFile(join(directory, 'moon.mod'), `name = "installcheck/moonhid-${version.replaceAll('.', '')}"\nversion = "0.0.0"\npreferred_target = "wasm"\n`);
await writeFile(join(directory, 'moon.pkg'), `import {\n  "${moduleName}" @moonhid,\n  "${moduleName}/examples",\n  "${moduleName}/transport",\n} for "test"\n`);
await writeFile(join(directory, 'verify_test.mbt'), await readFile(join(root, `docs/registry-${version}-test.mbt.txt`)));
const commands = [];
const moon = process.env.MOON_BIN ?? 'moon';
const run = args => {
  console.log(`Registry ${version}: moon ${args.join(' ')}`);
  const result = spawnSync(moon, args, { cwd: directory, encoding: 'utf8', timeout: 180000, maxBuffer: 16 * 1024 * 1024, windowsHide: true });
  commands.push({ command: ['moon', ...args], exit_code: result.status, output_tail: ((result.stdout ?? '') + (result.stderr ?? '')).slice(-4000) });
  assert.equal(result.status, 0, result.stderr || result.error?.message || result.stdout);
  return result.stdout ?? '';
};
run(['update']);
run(['add', `${moduleName}@${version}`]);
const installed = join(directory, '.mooncakes', ...moduleName.split('/'));
const installedMetadata = await readFile(join(installed, 'moon.mod'), 'utf8');
assert.match(installedMetadata, new RegExp(`^version\\s*=\\s*"${version.replaceAll('.', '\\.')}"`, 'm'));
const readmeRegular = (await lstat(join(installed, 'README.md'))).isFile();
assert.ok(readmeRegular, 'Published README must be a regular file.');
const consumerMetadata = await readFile(join(directory, 'moon.mod'), 'utf8');
assert.ok(!/\bpath\s*[:=]/.test(consumerMetadata), 'Local path override is forbidden.');
run(['check', '--target', 'all', '--deny-warn']);
const output = run(['test', 'verify_test.mbt', '--target', 'all']);
const tests = Object.fromEntries([...output.matchAll(/Total tests: (\d+), passed: (\d+), failed: (\d+)\. \[([^\]]+)\]/g)].map(([, total, passed, failed, target]) => [target, { total: Number(total), passed: Number(passed), failed: Number(failed) }]));
for (const target of ['wasm', 'wasm-gc', 'js', 'native']) assert.ok(tests[target]?.total >= 14 && tests[target].failed === 0, `Missing/failed ${target} API verification`);
const paths = git(['ls-tree', '-r', '--name-only', '-z', commit, '--', 'moon.mod', 'README.md', 'LICENSE', 'src']).toString().split('\0').filter(Boolean);
const sha = data => createHash('sha256').update(data).digest('hex');
const lf = data => data.toString('utf8').replaceAll('\r\n', '\n');
const files = [];
for (const path of paths) {
  const expected = git(['show', `${commit}:${path}`]);
  const actual = await readFile(join(installed, path));
  files.push({ path, published_sha256: sha(actual), git_sha256: sha(expected), raw_equal: actual.equals(expected), lf_normalized_equal: lf(actual) === lf(expected) });
}
assert.ok(files.length > 60 && files.every(file => file.lf_normalized_equal), 'Installed sources differ from the release Git commit.');
const report = {
  module: moduleName, version, recorded_at: new Date().toISOString(), registry_install: true, local_overrides: false,
  outside_repository: true, project_directory_name: basename(directory), git_ref: ref, git_commit: commit,
  platform: { os: process.platform, arch: process.arch, node: process.version },
  moon_toolchain: execFileSync(moon, ['version', '--all'], { encoding: 'utf8' }).trim(), commands, tests,
  readme_regular_file: readmeRegular,
  comparison: { count: files.length, raw_byte_matches: files.filter(file => file.raw_equal).length, lf_normalized_matches: files.filter(file => file.lf_normalized_equal).length, files },
};
await writeFile(reportPath, JSON.stringify(report, null, 2) + '\n');
console.log(`Registry ${version}: four backends each ${tests.wasm.total}/${tests.wasm.total}; ${files.length} files match Git after LF normalization (${report.comparison.raw_byte_matches} raw-byte matches). Report: ${reportPath}`);
