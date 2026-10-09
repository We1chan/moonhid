import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { inspect_descriptor, decode_wire } from '../web/moonhid-core.js';
import { lintRules, lintText } from '../web/lint-ui.js';
import { nullLesson } from '../web/lesson.js';
import { descriptorFromCollections } from '../web/browser-descriptor.js';
import { compareCollections } from '../web/hid-live.js';

const inspect = hex => JSON.parse(inspect_descriptor(hex));
const decode = fixture => JSON.parse(decode_wire(fixture.descriptor_hex, 'input', fixture.input_hex));
const before = inspect(nullLesson.before.descriptor_hex);
const after = inspect(nullLesson.after.descriptor_hex);
assert.equal(before.ok, true);
assert.equal(after.ok, true);
assert.deepEqual(before.descriptor.lints.map(l => [l.code, l.level, l.offset]), [['null_without_room', 'warning', 16]]);
assert.deepEqual(after.descriptor.lints, []);
assert.equal(decode(nullLesson.before).decoded.values[0].is_null, false);
assert.equal(decode(nullLesson.after).decoded.values[0].is_null, true);
assert.equal(before.descriptor.layout.reports[0].wire_bytes, 1);
assert.equal(after.descriptor.layout.reports[0].wire_bytes, 1);
assert.equal(Object.keys(lintRules).length, 10);
assert.equal(lintText({ code: 'future_code', level: 'info' }).title, '其他检查提示');
const axis = { reportSize: 16, reportCount: 2, logicalMinimum: 0, logicalMaximum: 65535, isConstant: false, isArray: false,
  isAbsolute: true, isLinear: true, hasPreferredState: true, hasNull: false, isVolatile: false, isBufferedBytes: false, wrap: false,
  isRange: false, usages: [0x10030, 0x10031] };
const collections = [{ usagePage: 1, usage: 5, type: 1, inputReports: [{ reportId: 1, items: [axis] }] }];
const reconstructed = inspect(descriptorFromCollections(collections));
assert.equal(reconstructed.ok, true);
assert.deepEqual(compareCollections(reconstructed.descriptor.layout, collections).differences, []);
assert.deepEqual(JSON.parse(decode_wire(descriptorFromCollections(collections), 'input', '01 00 00 ff ff')).decoded.values.map(v => v.value), [0, 65535]);
for (const kind of ['input', 'output', 'feature']) {
  for (const reportId of [0, 1, 127, 128, 255]) {
    const visible = [{ usagePage: 1, usage: 5, type: 1, [kind + 'Reports']: [{ reportId, items: [axis] }] }];
    const reference = descriptorFromCollections(visible);
    const result = inspect(reference);
    assert.equal(result.ok, true, `${kind} ID ${reportId}`);
    assert.deepEqual(compareCollections(result.descriptor.layout, visible).differences, []);
    const wire = (reportId ? reportId.toString(16).padStart(2, '0') + ' ' : '') + '00 00 ff ff';
    assert.deepEqual(JSON.parse(decode_wire(reference, kind, wire)).decoded.values.map(v => v.value), [0, 65535]);
  }
}
for (const type of [0, 1, 128, 255]) {
  const result = inspect(descriptorFromCollections([{ ...collections[0], type }]));
  assert.equal(result.ok, true, `Collection type ${type}`);
  assert.equal(result.descriptor.layout.collections[0].collection_type, type);
}
for (const usagePage of [0, 1, 0xff00, 0xffff]) {
  for (const usage of [0, 0x7fff, 0x8000, 0xffff]) {
    const result = inspect(descriptorFromCollections([{ ...collections[0], usagePage, usage }]));
    assert.equal(result.ok, true);
    assert.deepEqual(result.descriptor.layout.collections[0].usage, { page: usagePage, id: usage }, `Collection ${usagePage}:${usage}`);
  }
}
for (const usage of [-1, 0x10000, 1.5]) {
  assert.throws(() => descriptorFromCollections([{ ...collections[0], usage }]), /范围/);
}
for (const usagePage of [-1, 0x10000, 1.5]) {
  assert.throws(() => descriptorFromCollections([{ ...collections[0], usagePage }]), /范围/);
}
const zeroPage = [{ ...collections[0], inputReports: [{ reportId: 1, items: [{ ...axis, usages: [0x30, 0x10031] }] }] }];
const zeroPageReference = inspect(descriptorFromCollections(zeroPage));
assert.equal(zeroPageReference.ok, true);
assert.deepEqual(compareCollections(zeroPageReference.descriptor.layout, zeroPage).differences, []);
const zeroPageRange = [{ ...collections[0], inputReports: [{ reportId: 1, items: [{ ...axis, isRange: true, usageMinimum: 0x30, usageMaximum: 0x31 }] }] }];
const zeroPageRangeReference = inspect(descriptorFromCollections(zeroPageRange));
assert.equal(zeroPageRangeReference.ok, true);
assert.deepEqual(compareCollections(zeroPageRangeReference.descriptor.layout, zeroPageRange).differences, []);
for (const reportId of [-1, 256, 1.5]) {
  assert.throws(() => descriptorFromCollections([{ ...collections[0], inputReports: [{ reportId, items: [axis] }] }]), /范围/);
}
assert.throws(() => descriptorFromCollections([{ ...collections[0], outputReports: [{ reportId: 0, items: [axis] }] }]), /混用/);
const incomplete = [{ ...collections[0], inputReports: [{ reportId: 0, items: [{ ...axis, logicalMaximum: -1 }] }] }];
assert.throws(() => descriptorFromCollections(incomplete), /逻辑范围不完整/);
const rawReference = descriptorFromCollections(incomplete, { rawValues: true });
assert.equal(inspect(rawReference).descriptor.layout.fields[0].logical_max, 65535);
assert.deepEqual(JSON.parse(decode_wire(rawReference, 'input', '00 80 ff ff')).decoded.values.map(v => v.value), [32768, 65535]);
const xbox = JSON.parse(await readFile(new URL('../examples/device-cases/xbox-bluetooth.json', import.meta.url), 'utf8'));
assert.equal(xbox.reports.length, 42);
for (const report of xbox.reports) {
  const result = JSON.parse(decode_wire(xbox.reference_descriptor_hex, 'input', report.wire_hex));
  assert.equal(result.ok, true, `captured report ${report.sequence}`);
  assert.deepEqual(result.decoded.values.map(v => v.value), [...report.expected_axes, ...report.expected_buttons, report.expected_hat_raw]);
  assert.ok(result.decoded.values.every(v => v.in_logical_range && !v.is_null));
}
assert.equal(xbox.reports[0].expected_buttons[0], 1);
assert.equal(xbox.reports[1].expected_buttons[0], 0);
assert.equal(Math.min(...xbox.reports.map(r => r.expected_axes[0])), 0);
assert.equal(Math.max(...xbox.reports.map(r => r.expected_axes[0])), 65535);
assert.deepEqual(xbox.reports.at(-1).expected_axes, [32768, 32768, 32768, 32768, 32768]);
// The initial reconstruction is retained as evidence of incomplete metadata,
// rather than silently treating its 0..255 axis domain as the device protocol.
assert.equal(JSON.parse(decode_wire(xbox.initial_capture_reference_hex, 'input', xbox.reports.at(-1).wire_hex)).decoded.values[0].in_logical_range, false);
console.log('Guided case: compile success, located Warning, unchanged wire length and corrected Null decode passed.');
console.log('Xbox Bluetooth: 42 captured reports replayed; A press/release, X endpoints and return to centre passed against the explicit raw-value reference.');
