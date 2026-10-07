import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readdir, readFile, access } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join, resolve } from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const target = process.argv[2] ?? 'js';
assert.ok(['js', 'native'].includes(target));
const built = spawnSync('moon', ['build', 'cmd/moonhid', '--target', target, '--release'], { cwd: root, encoding: 'utf8' });
assert.equal(built.status, 0, built.stderr);
const directory = join(root, '_build', target, 'release/build/cmd/moonhid');
const binary = (await readdir(directory)).find(name => name.endsWith(target === 'js' ? '.js' : '.exe'));
assert.ok(binary, 'CLI output missing');
const executable = join(directory, binary);
const caseDirectory = resolve(root, process.argv[3] ?? 'examples/firmware-ci');
const fixture = name => join(caseDirectory, name);
const run = args => spawnSync(target === 'js' ? process.execPath : executable, target === 'js' ? [executable, ...args] : args, { cwd: root, encoding: 'utf8' });
if (await access(fixture('descriptor-before.hex')).then(() => true, () => false)) {
  const before = run(['lint', fixture('descriptor-before.hex')]);
  assert.equal(before.status, 3, before.stderr);
  assert.match(before.stdout, /warning /);
}
const after = run(['lint', fixture('descriptor.hex')]);
assert.equal(after.status, 0, after.stderr);
assert.equal(after.stdout, '');
const result = run(['decode', '--kind', 'input', fixture('descriptor.hex'), fixture('idle-report.hex')]);
assert.equal(result.status, 0, result.stderr);
const expected = JSON.parse(await readFile(fixture('expected.json'), 'utf8'));
const actual = JSON.parse(result.stdout).decoded.values.find(v => v.field_index === expected.field_index && v.element_index === expected.element_index);
for (const [key, value] of Object.entries(expected)) assert.equal(actual?.[key], value, `firmware expectation ${key}`);
console.log(`Firmware CI (${target}): pre-fix Warning, post-fix lint and recorded Null expectations passed.`);
