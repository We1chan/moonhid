import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, writeFile, rm, readdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const targets = process.argv[2] ? [process.argv[2]] : ['native', 'js'];
const scratch = await mkdtemp(join(tmpdir(), 'moonhid-cli-'));
const descriptor = join(scratch, '描述符 with spaces.hex');
const wire = join(scratch, 'report.hex');
const bad = join(scratch, 'bad.hex');
const length = join(scratch, 'short.hex');
const clean = join(scratch, '干净 descriptor.hex');
const info = join(scratch, 'info.hex');
const warning = join(scratch, 'warning.hex');
const warningAndInfo = join(scratch, 'warning and info.hex');
const compileError = join(scratch, 'compile-error.hex');
try {
  await writeFile(descriptor, '05 01 09 30 15 81 25 7f 75 08 95 01 81 06\n');
  await writeFile(wire, 'ff\n');
  await writeFile(bad, '05 q1');
  await writeFile(length, 'ff ff');
  await writeFile(clean, '05 01 09 05 a1 01 15 00 25 01 75 08 95 01 09 30 81 02 c0');
  await writeFile(info, '05 01 09 05 a1 01 15 00 25 ff 75 08 95 01 09 30 81 02 c0');
  await writeFile(warning, '05 01 09 05 a1 01 15 00 25 01 75 08 95 01 09 30 09 31 81 02 c0');
  await writeFile(warningAndInfo, '05 01 09 05 a1 01 15 00 25 ff 75 08 95 01 09 30 09 31 81 02 c0');
  await writeFile(compileError, '75');
  for (const target of targets) {
    assert.ok(['native', 'js'].includes(target));
    const build = spawnSync('moon', ['build', 'cmd/moonhid', '--target', target, '--release'], { cwd: root, encoding: 'utf8' });
    assert.equal(build.status, 0, build.stderr);
    const directory = join(root, '_build', target, 'release/build/cmd/moonhid');
    const name = (await readdir(directory)).find(name => target === 'js' ? name.endsWith('.js') : name.endsWith('.exe'));
    assert.ok(name, `CLI output missing for ${target}`);
    const path = join(directory, name);
    const run = args => spawnSync(target === 'js' ? process.execPath : path, target === 'js' ? [path, ...args] : args, { cwd: scratch, encoding: 'utf8' });
    const inspect = run(['inspect', descriptor]);
    assert.equal(inspect.status, 0, inspect.stderr);
    assert.equal(inspect.stderr, '');
    const inspected = JSON.parse(inspect.stdout);
    assert.equal(inspected.schema_version, 2);
    assert.ok(inspected.lints.some(l => l.code === 'field_outside_application' && l.level === 'warning'));
    const decoded = run(['decode', '--kind', 'input', descriptor, wire]);
    assert.equal(decoded.status, 0, decoded.stderr);
    assert.equal(decoded.stderr, '');
    assert.equal(JSON.parse(decoded.stdout).decoded.values[0].value, -1);
    for (const [args, status, message] of [
      [[], 2, /arguments @0/],
      [['decode', '--kind', 'invalid', descriptor, wire], 2, /report_kind @0/],
      [['inspect', bad], 1, /invalid_hex @3/],
      [['inspect', join(scratch, 'missing.hex')], 1, /file_read @0/],
      [['decode', '--kind', 'input', descriptor, length], 1, /report_length @2/],
      [['lint'], 2, /arguments @0/],
      [['lint', descriptor, wire], 2, /arguments @0/],
      [['lint', bad], 1, /invalid_hex @3/],
      [['lint', compileError], 1, /truncated_item @0/],
      [['lint', join(scratch, 'missing.hex')], 1, /file_read @0/],
    ]) {
      const result = run(args);
      assert.equal(result.status, status, result.stderr);
      assert.equal(result.stdout, '');
      assert.match(result.stderr, message);
    }
    const cleanLint = run(['lint', clean]);
    assert.equal(cleanLint.status, 0, cleanLint.stderr);
    assert.equal(cleanLint.stdout, '');
    assert.equal(cleanLint.stderr, '');
    for (const [file, status, patterns] of [
      [info, 0, [/^info logical_max_sign @8: .+/]],
      [warning, 3, [/^warning usage_count @18: .+/]],
      [warningAndInfo, 3, [/^info logical_max_sign @8: .+/, /^warning usage_count @18: .+/]],
    ]) {
      const result = run(['lint', file]);
      assert.equal(result.status, status, result.stderr);
      assert.equal(result.stderr, '');
      assert.ok(result.stdout.endsWith('\n'));
      const lines = result.stdout.trimEnd().split('\n');
      assert.equal(lines.length, patterns.length);
      lines.forEach((line, i) => assert.match(line, patterns[i]));
    }
    const warningInspect = run(['inspect', warning]);
    assert.equal(warningInspect.status, 0, warningInspect.stderr);
    assert.equal(JSON.parse(warningInspect.stdout).lints[0].level, 'warning');
    const help = run(['--help']);
    assert.equal(help.status, 0);
    assert.match(help.stdout, /moonhid lint <descriptor\.hex>/);
    console.log(`CLI ${target}: inspect/decode/lint, Unicode paths, stderr and exit codes 0/1/2/3 passed.`);
  }
} finally {
  await rm(scratch, { recursive: true, force: true });
}
