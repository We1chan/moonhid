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
    const build = spawnSync('moon', ['build', 'src/cmd/moonhid', '--target', target, '--release'], { cwd: root, encoding: 'utf8' });
    assert.equal(build.status, 0, build.stderr);
    const directory = join(root, '_build', target, 'release/build/cmd/moonhid');
    const name = (await readdir(directory)).find(name => target === 'js' ? name.endsWith('.js') : name.endsWith('.exe'));
    assert.ok(name, `CLI output missing for ${target}`);
    const path = join(directory, name);
    // Native stdout uses CRLF on Windows; compare text with LF line endings.
    const lf = text => (text ?? '').replace(/\r\n/g, '\n');
    const run = args => {
      const result = spawnSync(target === 'js' ? process.execPath : path, target === 'js' ? [path, ...args] : args, { cwd: scratch, encoding: 'utf8' });
      return { ...result, stdout: lf(result.stdout), stderr: lf(result.stderr) };
    };
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
    const valuesPath = join(scratch, '编码值 with spaces.json');
    await writeFile(valuesPath, '[-1]');
    const encoded = run(['encode', '--kind', 'input', '--id', '0', descriptor, valuesPath]);
    assert.equal(encoded.status, 0, encoded.stderr);
    assert.equal(encoded.stdout, 'ff\n');
    assert.equal(encoded.stderr, '');
    const generatedPath = join(scratch, 'generated.hex');
    const generatedWire = join(scratch, 'generated-report.hex');
    for (const [template, id, values, hex] of [
      ['mouse', 0, [1, 0, 1, -1, 2, -2], '05 ff 02 fe'],
      ['keyboard', 0, [0, 1, 0, 0, 0, 0, 0, 0, 4, 6, 0, 0, 0, 0], '02 00 04 06 00 00 00 00'],
      ['gamepad', 7, [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, -32768, 32767], '07 01 08 00 80 ff 7f'],
      ['consumer', 0, [0xe9], 'e9 00'],
      ['vendor', 0, Array.from({ length: 64 }, (_, i) => i), Array.from({ length: 64 }, (_, i) => i).map(i => i.toString(16).padStart(2, '0')).join(' ')],
    ]) {
      const generated = run(['generate', template]);
      assert.equal(generated.status, 0, generated.stderr);
      assert.equal(generated.stderr, '');
      await writeFile(generatedPath, generated.stdout);
      await writeFile(valuesPath, JSON.stringify(values));
      const encoded = run(['encode', '--kind', 'input', '--id', String(id), generatedPath, valuesPath]);
      assert.equal(encoded.status, 0, encoded.stderr);
      assert.equal(encoded.stdout, `${hex}\n`);
      await writeFile(generatedWire, encoded.stdout);
      const roundtrip = run(['decode', '--kind', 'input', generatedPath, generatedWire]);
      assert.equal(roundtrip.status, 0, roundtrip.stderr);
      assert.deepEqual(JSON.parse(roundtrip.stdout).decoded.values.map(v => v.value), values);
      if (template === 'keyboard') {
        await writeFile(valuesPath, '[1,1,0,0,0]');
        const leds = run(['encode', '--kind', 'output', '--id', '0', generatedPath, valuesPath]);
        assert.equal(leds.status, 0, leds.stderr);
        assert.equal(leds.stdout, '03\n');
      }
    }
    // Usage form: start from new_report, then set values and on/off Usages.
    const usage = (page, id, extra = {}) => ({ page, id, ...extra });
    for (const [template, kind, id, edits, hex] of [
      ['keyboard', 'input', 0, { active: [usage(7, 0xe1), usage(7, 4), usage(7, 6)] }, '02 00 04 06 00 00 00 00'],
      ['keyboard', 'output', 0, { active: [usage(8, 1), usage(8, 2)] }, '03'],
      ['keyboard', 'input', 0, {}, '00 00 00 00 00 00 00 00'],
      ['gamepad', 'input', 7, { values: [usage(1, 0x30, { value: -32768 }), usage(1, 0x31, { value: 32767 })], active: [usage(9, 1), usage(9, 12)] }, '07 01 08 00 80 ff 7f'],
      ['mouse', 'input', 0, { values: [usage(1, 0x30, { value: -1 }), usage(1, 0x31, { value: 2 }), usage(1, 0x38, { value: -2 })], active: [usage(9, 1), usage(9, 3)] }, '05 ff 02 fe'],
      ['mouse', 'input', 0, { physical: [usage(1, 0x30, { value: -1.4 })] }, '00 ff 00 00'],
      ['consumer', 'input', 0, { active: [usage(12, 0xcd)] }, 'cd 00'],
    ]) {
      await writeFile(generatedPath, run(['generate', template]).stdout);
      await writeFile(valuesPath, JSON.stringify(edits));
      const encoded = run(['encode', '--kind', kind, '--id', String(id), generatedPath, valuesPath]);
      assert.equal(encoded.status, 0, encoded.stderr);
      assert.equal(encoded.stdout, `${hex}\n`);
    }
    await writeFile(generatedPath, run(['generate', 'keyboard']).stdout);
    for (const [edits, code] of [
      ['{"extra":[]}', 'values_json'],
      ['{"active":{}}', 'values_json'],
      ['{"active":[{"page":7,"id":4,"x":1}]}', 'values_json'],
      ['{"active":[{"page":7,"id":70000}]}', 'values_json'],
      ['{"active":[{"page":7,"id":4.5}]}', 'values_json'],
      ['{"active":[{"page":7,"id":300}]}', 'unknown_usage'],
      ['{"values":[{"page":7,"id":4,"value":1}]}', 'unknown_usage'],
      ['{"values":[{"page":7,"id":225}]}', 'values_json'],
      [JSON.stringify({ active: [4, 5, 6, 7, 8, 9, 10].map(i => usage(7, i)) }), 'array_full'],
    ]) {
      await writeFile(valuesPath, edits);
      const error = run(['encode', '--kind', 'input', '--id', '0', generatedPath, valuesPath]);
      assert.equal(error.status, 1, error.stderr);
      assert.equal(error.stdout, '');
      assert.match(error.stderr, new RegExp(`^${code} @`));
    }
    await writeFile(generatedPath, '85 07 75 03 95 01 b1 01 75 21 b1 02');
    await writeFile(valuesPath, '[{"hex":"ff ff ff ff 01"}]');
    const raw = run(['encode', '--kind', 'feature', '--id', '7', generatedPath, valuesPath]);
    assert.equal(raw.status, 0, raw.stderr);
    assert.equal(raw.stdout, '07 f8 ff ff ff 0f\n');
    await writeFile(valuesPath, '[{"hex":"ff ff ff ff 02"}]');
    const badRaw = run(['encode', '--kind', 'feature', '--id', '7', generatedPath, valuesPath]);
    assert.equal(badRaw.status, 1);
    assert.match(badRaw.stderr, /value_range @/);
    assert.equal(badRaw.stdout, '');
    for (const [json, code] of [['true', 'values_json'], ['[1.5]', 'values_json'], ['[true]', 'values_json'], ['[', 'values_json'], ['[]', 'value_count'], ['[128]', 'value_range'], ['[-128]', 'logical_range'], ['[4294967296]', 'value_range'], ['[{"hex":"00","extra":1}]', 'values_json'], ['[{"hex":"zz"}]', 'invalid_hex']]) {
      await writeFile(valuesPath, json);
      const error = run(['encode', '--kind', 'input', '--id', '0', descriptor, valuesPath]);
      assert.equal(error.status, 1, error.stderr);
      assert.equal(error.stdout, '');
      assert.match(error.stderr, new RegExp(`^${code} @`));
    }
    await writeFile(valuesPath, '[-1]');
    for (const [args, status, message] of [
      [[], 2, /arguments @0/],
      [['decode', '--kind', 'invalid', descriptor, wire], 2, /report_kind @0/],
      [['generate', 'invalid'], 2, /template @0/],
      [['encode', '--kind', 'invalid', '--id', '0', descriptor, valuesPath], 2, /report_kind @0/],
      [['encode', '--kind', 'input', '--id', '256', descriptor, valuesPath], 2, /report_id @0/],
      [['encode', '--kind', 'input', '--id', 'abc', descriptor, valuesPath], 2, /report_id @0/],
      [['encode', '--kind', 'input', '--id', '1', descriptor, valuesPath], 1, /unknown_report @0/],
      [['encode', '--kind', 'input', '--id', '0', descriptor, join(scratch, 'missing.json')], 1, /file_read @0/],
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
    assert.match(help.stdout, /moonhid encode --kind/);
    assert.match(help.stdout, /moonhid generate mouse\|keyboard\|gamepad\|consumer\|vendor/);
    console.log(`CLI ${target}: inspect/decode/lint/encode (positional and Usage form)/generate (five templates), Unicode paths, raw Feature and exit codes 0/1/2/3 passed.`);
  }
} finally {
  await rm(scratch, { recursive: true, force: true });
}
