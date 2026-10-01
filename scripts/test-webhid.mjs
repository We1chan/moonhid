import assert from 'node:assert/strict';
import { inputWireHex, compareCollections, createHIDController } from '../web/hid-live.js';
import { inspect_descriptor } from '../web/moonhid-core.js';

const buffer = new Uint8Array([99, 255, 127, 88]).buffer;
assert.equal(inputWireHex(7, new DataView(buffer, 1, 2)), '07 ff 7f');
assert.equal(inputWireHex(0, new DataView(buffer, 1, 2)), 'ff 7f');
assert.throws(() => inputWireHex(256, new DataView(buffer)));
assert.throws(() => inputWireHex(1, new DataView(new ArrayBuffer(8193))));
const layout = JSON.parse(inspect_descriptor('05 01 19 00 2a ff 7f 15 00 26 ff 7f 75 10 95 01 85 03 81 00')).descriptor.layout;
const item = {
  reportSize: 16, reportCount: 1, isConstant: false, isArray: true, isAbsolute: true, isLinear: true,
  hasPreferredState: true, hasNull: false, isVolatile: false, isBufferedBytes: false, wrap: false,
  logicalMinimum: 0, logicalMaximum: 32767, isRange: true, usageMinimum: 0x10000, usageMaximum: 0x17fff,
};
const collection = { inputReports: [{ reportId: 3, items: [item] }], children: [{ inputReports: [{ reportId: 3, items: [item] }] }] };
assert.deepEqual(compareCollections(layout, [collection]), { comparedFields: 1, differences: [] });
const different = { inputReports: [{ reportId: 3, items: [{ ...item, reportCount: 2, logicalMaximum: 1 }] }] };
assert.equal(compareCollections(layout, [different]).differences.length, 2);
assert.match(compareCollections(layout, []).differences[0], /浏览器未暴露/);
assert.match(compareCollections(layout, [{ inputReports: [{ reportId: 4, items: [item] }] }]).differences.at(-1), /没有此报告/);

class Device extends EventTarget {
  opened = false;
  closes = 0;
  collections = [collection];
  async open() { this.opened = true; }
  async close() { this.opened = false; this.closes++; }
  emit(id = 3) { this.dispatchEvent(Object.assign(new Event('inputreport'), { device: this, reportId: id, data: new DataView(buffer, 1, 2) })); }
}
const hid = new EventTarget();
const device = new Device();
hid.requestDevice = async options => { assert.deepEqual(options, { filters: [] }); return [device]; };
const states = [], reports = [];
const controller = createHIDController(hid, { onState: state => states.push(state), onReport: report => reports.push(report) });
await controller.connect();
assert.equal(controller.device, device);
device.emit();
assert.equal(reports[0].wireHex, '03 ff 7f');
assert.equal(reports[0].received, 1);
await controller.disconnect();
assert.equal(device.closes, 1);
device.emit();
assert.equal(reports.length, 1);
await controller.connect();
hid.dispatchEvent(Object.assign(new Event('disconnect'), { device }));
assert.equal(controller.device, null);
assert.equal(states.at(-1).status, 'unplugged');
device.emit();
assert.equal(reports.length, 1);
await controller.dispose();

let finishOpen;
const opening = new Device();
opening.open = async () => { await new Promise(resolve => { finishOpen = resolve; }); opening.opened = true; };
hid.requestDevice = async () => [opening];
const race = createHIDController(hid, { onState() {}, onReport() {} });
const connecting = race.connect();
await new Promise(resolve => setImmediate(resolve));
await race.disconnect();
finishOpen();
await connecting;
assert.equal(race.device, null);
assert.equal(opening.closes, 1);
await race.dispose();
console.log('WebHID: ID prefix, DataView slice, collections, disconnect/unplug and pending-open cancellation passed.');
