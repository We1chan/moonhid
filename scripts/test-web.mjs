import assert from 'node:assert/strict';
import { inspect_descriptor, decode_wire, initialize_wire, write_wire_field, examples_json } from '../web/moonhid-core.js';

const inspect = hex => JSON.parse(inspect_descriptor(hex));
const decode = (descriptor, kind, wire) => JSON.parse(decode_wire(descriptor, kind, wire));
const initialize = (descriptor, kind, id = 0) => JSON.parse(initialize_wire(descriptor, kind, id));
const write = (descriptor, kind, wire, field, element, value) => JSON.parse(write_wire_field(descriptor, kind, wire, field, element, value));
const fixtures = JSON.parse(examples_json());
assert.deepEqual(fixtures.map(f => f.name), ['mouse', 'keyboard', 'gamepad']);
for (const fixture of fixtures) {
  const result = inspect(fixture.descriptor_hex);
  assert.equal(result.ok, true);
  assert.equal(result.schema_version, 2);
  assert.deepEqual(result.descriptor.lints, []);
  assert.equal(result.descriptor.layout.collections[0].parent_index, null);
  const report = decode(fixture.descriptor_hex, 'input', fixture.input_hex);
  assert.equal(report.ok, true);
  assert.deepEqual(report.decoded.values.map(v => v.value), fixture.expected_values);
  assert.ok(report.decoded.values.every(v => v.in_logical_range));
  assert.equal(result.descriptor.layout.reports.find(r => r.kind === 'input').wire_bytes, fixture.input_hex.split(' ').length);
}
const keyboard = fixtures.find(f => f.name === 'keyboard');
assert.deepEqual(decode(keyboard.descriptor_hex, 'output', keyboard.output_hex).decoded.values.map(v => v.value), [1, 1, 0, 0, 0]);
assert.equal(decode(keyboard.descriptor_hex, 'input', '00').error.code, 'report_length');
assert.equal(decode(keyboard.descriptor_hex, 'feature', '00').error.code, 'unknown_report');
assert.equal(decode(keyboard.descriptor_hex, 'invalid', '00').error.code, 'report_kind');
assert.deepEqual([inspect('05 q1').stage, inspect('05 q1').error.offset], ['descriptor_hex', 3]);
assert.equal(inspect('75').error.code, 'truncated_item');
assert.equal(inspect('75 08 95 01 81 02 fe 01 80 01').error.code, 'unsupported_item');
assert.equal(decode(keyboard.descriptor_hex, 'input', '0x00').stage, 'report_hex');
const composite = '75 08 95 01 85 01 15 00 25 ff 81 02 91 02 85 02 15 81 25 7f 81 02 b1 02';
assert.deepEqual(inspect(composite).descriptor.layout.reports.map(r => [r.kind, r.report_id]), [['input', 1], ['output', 1], ['input', 2], ['feature', 2]]);
assert.equal(decode(composite, 'input', '02 ff').decoded.values[0].value, -1);
assert.equal(decode(composite, 'feature', '02 ff').decoded.values[0].value, -1);
assert.equal(decode(composite, 'input', '03 ff').error.code, 'unknown_report');
const metadata = '05 01 09 02 a1 01 09 01 a1 00 15 81 25 7f 36 99 f3 46 67 0c 55 0c 65 13 75 08 95 01 09 30 81 06 c0 c0';
const layout = inspect(metadata).descriptor.layout;
assert.deepEqual(layout.collections.map(c => c.parent_index), [null, 0]);
assert.equal(layout.fields[0].collection_index, 1);
assert.equal(layout.fields[0].physical_min, -3175);
assert.equal(layout.fields[0].unit_exponent, -4);
assert.deepEqual([layout.fields[0].unit.system, layout.fields[0].unit.length], [3, 1]);
const unsigned = '15 00 27 ff ff ff ff 75 20 95 01 81 02';
assert.equal(inspect(unsigned).descriptor.layout.fields[0].logical_max, 4294967295);
assert.equal(decode(unsigned, 'input', 'ff ff ff ff').decoded.values[0].value, 4294967295);
const zero = 'a0 04 14 24 34 44 54 64 75 01 95 01 08 80 c0';
assert.equal(inspect(zero).descriptor.layout.collections[0].collection_type, 0);
assert.equal(decode(zero, 'input', '00').decoded.values[0].value, 0);
assert.equal(inspect('84').error.code, 'report_id');
assert.equal(inspect('94').error.code, 'report_count');
assert.equal(inspect('74 95 01 80').error.code, 'missing_dimensions');
assert.equal(inspect('75 01 95 01 82 00 01').error.code, 'buffered_alignment');
const buffered = '06 00 ff 09 01 a1 01 85 05 15 00 25 01 75 08 95 04 09 02 82 02 01 09 03 92 02 01 09 04 b2 02 01 c0';
assert.deepEqual(inspect(buffered).descriptor.lints, []);
for (const [index, kind] of ['input', 'output', 'feature'].entries()) {
  const report = decode(buffered, kind, '05 4d 4f 4f 4e');
  assert.equal(report.ok, true);
  assert.deepEqual(report.decoded.values, []);
  assert.deepEqual(report.decoded.opaque_values, []);
  assert.deepEqual(report.decoded.buffered_values, [{ field_index: index, bit_offset: 0, hex: '4d 4f 4f 4e' }]);
}
assert.equal(inspect('75 08 95 01 82 00 02').error.code, 'main_flags');
const opaque = '85 07 75 03 95 01 81 01 75 21 81 02';
const raw = decode(opaque, 'input', '07 ff ff ff ff ff');
assert.equal(raw.schema_version, 2);
assert.deepEqual(raw.decoded.values, []);
assert.deepEqual(raw.decoded.opaque_values, [{ field_index: 1, element_index: 0, bit_offset: 3, bit_size: 33, hex: 'ff ff ff ff 01' }]);
assert.equal(inspect('75 21 95 01 81 00').error.code, 'report_size');
const count1751 = inspect('15 00 25 ff 75 08 96 d7 06 81 02');
assert.equal(count1751.descriptor.layout.fields[0].count, 1751);
assert.equal(count1751.descriptor.layout.reports[0].payload_bits, 14008);
assert.equal(inspect('75 02 97 00 00 01 00 81 02').error.code, 'report_limit');
const usageSpan = '05 01 19 00 2a ff 7f 15 00 26 ff 7f 75 10 95 01 81 00';
assert.deepEqual(inspect(usageSpan).descriptor.layout.fields[0].usage_spans, [{ page: 1, min: 0, max: 32767 }]);
assert.equal(inspect(usageSpan).descriptor.layout.fields[0].usage_count, 32768);
assert.deepEqual(decode(usageSpan, 'input', 'ff 7f').decoded.values[0].usage, { page: 1, id: 32767 });
assert.equal(inspect('09 01 '.repeat(1025)).error.code, 'usage_limit');
const local = inspect('7b ff ff ff ff 39 03 75 08 95 01 81 02').descriptor.layout.fields[0];
assert.deepEqual(local.string_spans, [{ min: 4294967295, max: 4294967295 }]);
assert.deepEqual(local.designator_spans, [{ min: 3, max: 3 }]);
const delimiter = inspect('05 09 a9 01 09 01 a8 a9 01 09 02 a8 75 01 95 01 81 02').descriptor.layout.fields[0];
assert.deepEqual(delimiter.usage_spans, [{ page: 9, min: 1, max: 1 }]);
assert.deepEqual(delimiter.alternate_usages, [[{ page: 9, min: 2, max: 2 }]]);
assert.equal(inspect('a9 00').error.code, 'delimiter');
assert.equal(inspect('99 02').error.code, 'local_range');
assert.equal(inspect('79 01 '.repeat(1025)).error.code, 'local_limit');

// Browser writes use core validation and independent, fixed wire expectations.
assert.equal(initialize(keyboard.descriptor_hex, 'output').wire_hex, '00');
assert.equal(write(keyboard.descriptor_hex, 'output', 'e0', 3, 0, '1').wire_hex, 'e1');
const keyArray = inspect(keyboard.descriptor_hex).descriptor.layout.fields.findIndex(field => field.kind === 'input' && !(field.flags & 3));
const pressed = write(keyboard.descriptor_hex, 'input', '00 00 00 00 00 00 00 00', keyArray, 2, '4');
assert.equal(pressed.wire_hex, '00 00 00 00 04 00 00 00');
assert.deepEqual(pressed.decoded.values.find(value => value.field_index === keyArray && value.element_index === 2).usage, { page: 7, id: 4 });
const packed = '85 07 15 00 26 ff 0f 75 03 95 01 81 01 75 0c 81 02 75 01 81 01';
assert.equal(initialize(packed, 'input', 7).wire_hex, '07 00 00');
// Payload 0xFFFF -> (0x123 << 3) | 0x8007 = 0x891F: both pads remain set.
assert.equal(write(packed, 'input', '07 ff ff', 1, 0, '291').wire_hex, '07 1f 89');
assert.equal(write(unsigned, 'input', '00 00 00 00', 0, 0, '4294967295').wire_hex, 'ff ff ff ff');
const signed32 = '17 00 00 00 80 27 ff ff ff 7f 75 20 95 01 81 02';
assert.equal(write(signed32, 'input', '00 00 00 00', 0, 0, '-2147483648').wire_hex, '00 00 00 80');
assert.equal(write(composite, 'input', '02 00', 2, 0, '-1').wire_hex, '02 ff');
assert.equal(write(composite, 'input', '02 00', 2, 0, '-128').error.code, 'logical_range');
assert.equal(write(unsigned, 'input', '00 00 00 00', 0, 0, '4294967296').error.code, 'value_range');
assert.equal(write(opaque, 'input', '07 ff ff ff ff ff', 1, 0, '00 00 00 00 00').wire_hex, '07 07 00 00 00 f0');
assert.equal(write(opaque, 'input', '07 ff ff ff ff ff', 1, 0, 'ff ff ff ff ff').error.code, 'value_range');
const hat = '05 01 09 39 15 00 25 07 75 04 95 01 81 42';
assert.equal(initialize(hat, 'input').wire_hex, '0f');
assert.equal(write(hat, 'input', 'af', 0, 0, '2').wire_hex, 'a2');
assert.equal(write(hat, 'input', 'a2', 0, 0, '15').decoded.values[0].is_null, true);
for (const [index, kind] of ['input', 'output', 'feature'].entries()) {
  assert.equal(initialize(buffered, kind, 5).wire_hex, '05 00 00 00 00');
  const stream = write(buffered, kind, '05 00 00 00 00', index, 0, '00 ff 01 80');
  assert.equal(stream.wire_hex, '05 00 ff 01 80');
  assert.equal(stream.decoded.buffered_values[0].hex, '00 ff 01 80');
  assert.equal(write(buffered, kind, stream.wire_hex, index, 1, '00 ff 01 80').error.code, 'element_index');
  assert.equal(write(buffered, kind, stream.wire_hex, index, 0, '00 ff').error.code, 'value_range');
  assert.deepEqual([write(buffered, kind, stream.wire_hex, index, 0, '00 zz').stage, write(buffered, kind, stream.wire_hex, index, 0, '00 zz').error.offset], ['field_value_hex', 3]);
}
for (const value of ['', '1.5', '1e2', '0xff', '9223372036854775808']) {
  const result = write(packed, 'input', '07 ff ff', 1, 0, value);
  assert.equal(result.ok, false, value);
  assert.equal(result.stage, 'field_value', value);
}
for (const [field, element, code] of [[-1, 0, 'field_index'], [1, -1, 'element_index'], [1, 1, 'element_index'], [0, 0, 'constant_field']]) {
  assert.equal(write(packed, 'input', '07 ff ff', field, element, '0').error.code, code);
}
assert.equal(write(composite, 'input', '02 00', 0, 0, '0').error.code, 'field_report');
assert.equal(write(packed, 'input', '07', 1, 0, '0').error.code, 'report_length');
assert.equal(write(packed, 'input', '07 zz ff', 1, 0, '0').stage, 'report_hex');
assert.equal(initialize(packed, 'invalid', 7).error.code, 'report_kind');
assert.equal(initialize(packed, 'feature', 7).error.code, 'unknown_report');
assert.equal(initialize(packed, 'input', 8).error.code, 'unknown_report');
assert.equal(initialize('zz', 'input').stage, 'descriptor_hex');
assert.equal(initialize('75', 'input').stage, 'descriptor');

// Assert the JSON contract for every lint code, including optional field_index
// and stable item offsets. Warnings must not become bridge failure responses.
const app = body => `05 01 09 05 a1 01 ${body} c0`;
const globals = '05 01 15 00 25 01 75 08 95 01';
for (const [hex, code, level, offset, fieldIndex] of [
  [app('15 00 25 ff 75 08 95 01 09 30 81 02'), 'logical_max_sign', 'info', 8, 0],
  [app('15 00 25 01 75 08 95 01 35 00 45 ff 09 30 81 02'), 'physical_max_sign', 'info', 16, 0],
  [app('15 00 25 0f 75 04 95 01 09 39 81 42'), 'null_without_room', 'warning', 16, 0],
  [app('05 09 19 01 29 03 15 00 25 01 75 02 95 02 81 02'), 'usage_count', 'warning', 20, 0],
  [app('05 09 19 01 29 03 15 00 25 01 75 02 95 04 81 02'), 'usage_count', 'info', 20, 0],
  [app('15 00 25 01 75 08 95 01 81 02'), 'missing_usage', 'warning', 14, 0],
  [app('15 00 25 01 75 03 95 01 09 30 81 02'), 'unaligned_report', 'info', 16, 0],
  ['05 01 09 30 15 81 25 7f 75 08 95 01 81 06', 'field_outside_application', 'warning', 12, 0],
  ['05 01 a1 01 15 00 25 01 75 08 95 01 09 30 81 02 c0', 'collection_without_usage', 'warning', 2, null],
  [`${globals} 09 05 a1 01 09 30 81 02 c0 09 02 a1 01 09 31 81 02 c0`, 'multiple_applications_without_report_id', 'warning', 21, null],
  [`${globals} 09 05 a1 01 85 01 09 30 81 02 c0 09 02 a1 01 85 01 09 31 81 02 c0`, 'report_id_shared_across_applications', 'warning', 29, 1],
]) {
  const result = inspect(hex);
  assert.equal(result.ok, true);
  assert.equal(result.schema_version, 2);
  assert.equal(result.descriptor.schema_version, 2);
  const matches = result.descriptor.lints.filter(l => l.code === code);
  assert.equal(matches.length, 1, code);
  const entry = matches[0];
  assert.deepEqual([entry.level, entry.offset, entry.field_index], [level, offset, fieldIndex], code);
  assert.equal(typeof entry.message, 'string');
  assert.ok(entry.message.length > 0);
  assert.ok(result.descriptor.items.some(item => item.offset === entry.offset));
}
console.log('Browser bridge: fixtures, metadata, lint/JSON v2, initialization, field writes, padding/ID preservation, Array/Null/Raw/Buffered Bytes and errors passed.');
