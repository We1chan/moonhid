import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const fixtures = join(root, 'examples/codec');
const target = process.argv[2] ?? 'js';
assert.ok(['js', 'native'].includes(target), 'Usage: node scripts/test-compatibility.mjs [js|native]');
const build = spawnSync('moon', ['build', 'src/cmd/moonhid', '--target', target, '--release'], { cwd: root, stdio: 'inherit' });
if (build.error) throw build.error;
assert.equal(build.status, 0, 'CLI build failed');
const directory = join(root, '_build', target, 'release/build/cmd/moonhid');
const binaries = (await readdir(directory)).filter(name => name.endsWith(target === 'js' ? '.js' : '.exe'));
assert.equal(binaries.length, 1, 'Expected one CLI build output');
const executable = join(directory, binaries[0]);
const run = args => {
  const result = spawnSync(target === 'js' ? process.execPath : executable,
    target === 'js' ? [executable, ...args] : args, { cwd: root, encoding: 'utf8' });
  if (result.error) throw result.error;
  return { ...result, stdout: result.stdout.replace(/\r\n/g, '\n'), stderr: result.stderr.replace(/\r\n/g, '\n') };
};
const success = result => {
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stderr, '');
  return result.stdout.trim();
};
const manifest = JSON.parse(await readFile(join(fixtures, 'compatibility-cases.json'), 'utf8'));
// Compare both directions against saved, independently specified wire bytes.
// Decoding consumes the committed report fixture, not the encoder's output.
for (const sample of manifest.cases) {
  assert.ok(['standard', 'extension'].includes(sample.scope), sample.name);
  const descriptor = join(fixtures, sample.descriptor);
  const inspected = JSON.parse(success(run(['inspect', descriptor])));
  const fields = inspected.layout.fields.filter(field => field.kind === sample.kind && field.report_id === sample.id);
  const scalarViolations = [];
  for (const field of fields) {
    if ((field.flags & 256) !== 0) {
      // HID 1.11 section 6.2.2.5 defines these as application byte streams,
      // rather than scalar numeric fields subject to the section 8.4 check.
      assert.equal(field.bit_offset % 8, 0, sample.name);
      assert.equal(field.bit_size * field.count % 8, 0, sample.name);
      continue;
    }
    for (let element = 0; element < field.count; element++) {
      const offset = field.bit_offset + element * field.bit_size;
      const byteSpan = Math.ceil((offset % 8 + field.bit_size) / 8);
      if (byteSpan > 4) scalarViolations.push({ offset, bit_size: field.bit_size, byte_span: byteSpan });
    }
  }
  if (sample.scope === 'standard') {
    assert.deepEqual(scalarViolations, [], `${sample.name}: HID 1.11 section 8.4 scalar field limit`);
  } else {
    assert.ok(scalarViolations.length > 0, `${sample.name}: expected a documented wide-field extension`);
  }
  const saved = (await readFile(join(fixtures, sample.report), 'utf8')).trim();
  assert.equal(saved, sample.wire_hex, sample.name);
  const encoded = success(run(['encode', '--kind', sample.kind, '--id', String(sample.id), descriptor, join(fixtures, sample.values)]));
  assert.equal(encoded, sample.wire_hex, sample.name);
  const json = JSON.parse(success(run(['decode', '--kind', sample.kind, descriptor, join(fixtures, sample.report)])));
  assert.equal(json.schema_version, 2);
  assert.equal(json.wire_hex, sample.wire_hex);
  const decoded = json.decoded;
  assert.equal(decoded.kind, sample.kind);
  assert.equal(decoded.report_id, sample.id);
  assert.equal(sample.elements.length, sample.integers.length, `${sample.name}: complete independent element expectations`);
  const expectedValues = sample.elements.map((element, index) => ({
    ...element,
    value: sample.integers[index],
    in_logical_range: !(sample.null_indices ?? []).includes(index),
    is_null: (sample.null_indices ?? []).includes(index),
  }));
  assert.deepEqual(decoded.values, expectedValues, sample.name);
  assert.deepEqual(decoded.opaque_values, sample.opaque_values ?? [], sample.name);
  assert.deepEqual(decoded.buffered_values, sample.buffered_values ?? [], sample.name);
  console.log(`${sample.name} [${sample.scope}]: ${sample.kind} / ID ${sample.id} -> ${encoded}`);
}
const scratch = await mkdtemp(join(tmpdir(), 'moonhid-compatibility-'));
try {
  for (const rejection of manifest.rejections) {
    const sample = manifest.cases.find(sample => sample.name === rejection.case);
    assert.ok(sample, rejection.case);
    const path = join(scratch, rejection.operation === 'decode' ? 'report.hex' : 'values.json');
    await writeFile(path, rejection.operation === 'decode' ? rejection.wire_hex : JSON.stringify(rejection.values));
    const args = [rejection.operation, '--kind', sample.kind];
    if (rejection.operation === 'encode') args.push('--id', String(sample.id));
    const result = run([...args, join(fixtures, sample.descriptor), path]);
    assert.equal(result.status, 1, result.stderr);
    assert.equal(result.stdout, '');
    assert.ok(result.stderr.startsWith(`${rejection.code} @`), result.stderr);
  }
} finally {
  await rm(scratch, { recursive: true, force: true });
}
const standardCount = manifest.cases.filter(sample => sample.scope === 'standard').length;
const extensionCount = manifest.cases.filter(sample => sample.scope === 'extension').length;
console.log(`HID 1.11 (${target}): ${standardCount} standard fixed-wire cases, ${extensionCount} permissive extension case and ${manifest.rejections.length} rejection cases passed.`);
