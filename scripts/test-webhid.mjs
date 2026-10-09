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
let openingRequests = 0;
hid.requestDevice = async () => { openingRequests++; return [opening]; };
const openingStates = [];
const race = createHIDController(hid, { onState: state => openingStates.push(state), onReport() {} });
const connecting = race.connect();
await new Promise(resolve => setImmediate(resolve));
await race.disconnect();
assert.equal(race.busy, true, 'Cancelled open must finish cleanup before reconnecting');
await race.connect();
assert.equal(openingRequests, 1);
finishOpen();
await connecting;
assert.equal(race.device, null);
assert.equal(opening.closes, 1);
assert.equal(race.busy, false);
assert.equal(openingStates.at(-1).status, 'disconnected');
opening.open = Device.prototype.open;
await race.connect();
assert.equal(openingRequests, 2);
assert.equal(opening.opened, true);
await race.dispose();

// A slow close must block reconnects and repeated disconnects must await it.
const closeStarted = Promise.withResolvers();
const closeGate = Promise.withResolvers();
const slow = new Device();
slow.close = async () => { slow.closes++; closeStarted.resolve(); await closeGate.promise; slow.opened = false; };
let slowRequests = 0;
hid.requestDevice = async () => { slowRequests++; return [slow]; };
const slowStates = [], slowReports = [];
const serial = createHIDController(hid, { onState: state => slowStates.push(state), onReport: report => slowReports.push(report) });
await serial.connect();
const firstClose = serial.disconnect();
await closeStarted.promise;
assert.equal(serial.device, null);
assert.equal(serial.busy, true);
assert.equal(slowStates.at(-1).status, 'disconnecting');
assert.equal(slowStates.at(-1).busy, true);
let repeatedCloseFinished = false;
const repeatedClose = serial.disconnect().then(() => { repeatedCloseFinished = true; });
await serial.connect();
await new Promise(resolve => setImmediate(resolve));
assert.equal(repeatedCloseFinished, false);
assert.equal(serial.busy, true);
assert.equal(slowRequests, 1, 'Do not request the still-closing device again');
slow.emit();
assert.equal(slowReports.length, 0);
closeGate.resolve();
await Promise.all([firstClose, repeatedClose]);
assert.equal(slow.closes, 1);
assert.equal(slow.opened, false);
assert.equal(serial.busy, false);
assert.equal(slowStates.at(-1).status, 'disconnected');
await serial.connect();
assert.equal(slowRequests, 2);
assert.equal(slow.opened, true);
slow.emit();
assert.equal(slowReports.length, 1);
await serial.dispose();
await serial.connect();
assert.equal(slowRequests, 2, 'Disposed controllers cannot reconnect');
assert.equal(serial.device, null);

// Device-specific validation runs before open and shares the cancellation lock.
const configuredHID = new EventTarget();
const configuredDevice = new Device();
const filters = [{ usagePage: 1, usage: 5 }];
let configuredRequests = 0;
configuredHID.requestDevice = async options => { configuredRequests++; assert.deepEqual(options, { filters }); return [configuredDevice]; };
const preparationStarted = Promise.withResolvers();
const preparationGate = Promise.withResolvers();
const configured = createHIDController(configuredHID, {
  filters, onState() {}, onReport() {},
  beforeOpen: async candidate => { assert.equal(candidate, configuredDevice); preparationStarted.resolve(); await preparationGate.promise; },
});
const preparing = configured.connect();
await preparationStarted.promise;
await configured.disconnect();
await configured.connect();
assert.equal(configuredRequests, 1);
assert.equal(configured.busy, true);
preparationGate.resolve();
await preparing;
assert.equal(configuredDevice.opened, false);
assert.equal(configuredDevice.closes, 0);
assert.equal(configured.device, null);
assert.equal(configured.busy, false);
await configured.dispose();

// Close failures release the lock, remove the listener and preserve the error.
const failing = new Device();
failing.close = async () => { throw new Error('simulated close failure'); };
hid.requestDevice = async () => [failing];
const failureStates = [], failureReports = [];
const recovery = createHIDController(hid, { onState: state => failureStates.push(state), onReport: report => failureReports.push(report) });
await recovery.connect();
await recovery.disconnect();
assert.equal(recovery.device, null);
assert.equal(recovery.busy, false);
assert.equal(failureStates.at(-1).status, 'error');
assert.match(failureStates.at(-1).error, /simulated close failure/);
failing.emit();
assert.equal(failureReports.length, 0);
await recovery.connect();
failing.emit();
assert.equal(failureReports.length, 1);
failing.close = Device.prototype.close;
await recovery.dispose();
console.log('WebHID: ID prefix, DataView slice, collections, cancellation during prepare/open, serial close, close failure recovery and disposal passed.');
