import { descriptorFromCollections } from './browser-descriptor.js';
import { compareCollections, createHIDController } from './hid-live.js';
import { inspect_descriptor, decode_wire } from './moonhid-core.js';

const $ = id => document.getElementById(id);
const hidAvailable = Boolean(navigator.hid && isSecureContext);
let record = null, prepared = null;
const status = message => { $('capture-status').textContent = message; };
const controller = createHIDController(hidAvailable ? navigator.hid : null, {
  filters: [{ usagePage: 1, usage: 5 }, { usagePage: 1, usage: 4 }],
  beforeOpen: candidate => {
    const rawValues = $('capture-raw').checked;
    const reference = descriptorFromCollections(candidate.collections, { rawValues });
    const inspected = JSON.parse(inspect_descriptor(reference));
    if (!inspected.ok) throw new Error(`${inspected.error.code} @${inspected.error.offset}: ${inspected.error.message}`);
    prepared = { schema_version: 1, descriptor_source: rawValues ? 'webhid-bit-layout-raw-values' : 'webhid-visible-fields-reconstruction',
      limitations: `Reference layout only; not the original USB/BLE descriptor. No original item encodings, nested collection or physical/local metadata verification.${rawValues ? ' Uses representable bit ranges; original logical ranges, Array and Null semantics are unverified.' : ''}`,
      device: { declared_model: $('capture-model').value, product_name: candidate.productName, vendor_id: candidate.vendorId, product_id: candidate.productId },
      raw_values_mode: rawValues, browser_collections: candidate.collections,
      reference_descriptor_hex: reference, descriptor: inspected.descriptor,
      collections_comparison: compareCollections(inspected.descriptor.layout, candidate.collections) };
  },
  onState: next => {
    const locked = next.busy || Boolean(next.device);
    $('capture-connect').disabled = !hidAvailable || locked;
    $('capture-stop').disabled = !locked || next.status === 'disconnecting';
    $('capture-raw').disabled = locked;
    $('capture-model').disabled = locked;
    if (next.status === 'connected') {
      record = { ...prepared, captured_at: new Date().toISOString(), total_received: 0, reports: [] };
      $('capture-descriptor').value = record.reference_descriptor_hex;
      $('capture-record').value = '';
      $('capture-last').textContent = '等待实际 Input 报告';
      $('capture-export').disabled = true;
    }
    // Keep the record available even when close() fails or a connect is cancelled.
    if (!next.device && record) $('capture-record').value = JSON.stringify(record, null, 2);
    const labels = {
      connecting: '等待设备选择与连接…', disconnecting: '正在断开，请稍候…',
      connected: `${next.device?.productName || 'HID 手柄'} 已连接，请按 A 并移动摇杆。${record?.raw_values_mode ? '当前仅查看原始数值，不验证原始逻辑范围、Array 或 Null 语义。' : ''}`,
      disconnected: `已停止接收，保留 ${record?.reports.length ?? 0} 条报告。`,
      unplugged: '手柄已断开，记录保留。', cancelled: '没有选择手柄。',
      error: next.device ? `报告处理失败：${next.error}` : next.error?.startsWith('关闭连接失败') ? next.error.replace('关闭连接失败', '关闭失败') : `连接失败：${next.error}`,
    };
    status(labels[next.status]);
  },
  onReport: entry => {
    const decoded = JSON.parse(decode_wire(record.reference_descriptor_hex, 'input', entry.wireHex));
    record.reports.push({ sequence: entry.received, report_id: entry.reportId, wire_hex: entry.wireHex, result: decoded });
    if (record.reports.length > 100) record.reports.shift();
    record.total_received = entry.received;
    $('capture-last').textContent = JSON.stringify(record.reports.at(-1), null, 2);
    $('capture-export').disabled = false;
    status(`${entry.device.productName || 'HID 手柄'} · 已收到 ${entry.received} 条报告；保留最近 ${record.reports.length} 条。${record.raw_values_mode ? ' 按位宽查看原始值。' : ''}`);
  },
});
$('capture-connect').addEventListener('click', () => { void controller.connect(); });
$('capture-stop').addEventListener('click', () => { void controller.disconnect(); });
$('capture-export').addEventListener('click', () => {
  if (!record) return;
  const url = URL.createObjectURL(new Blob([JSON.stringify(record, null, 2) + '\n'], { type: 'application/json' }));
  const link = document.createElement('a'); link.href = url; link.download = 'moonhid-device-validation.json'; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
});
window.addEventListener('pagehide', () => { void controller.disconnect(); });
if (!hidAvailable) { $('capture-connect').disabled = true; status('WebHID 不可用，请使用 Chromium、HTTPS 或 localhost。'); }
else status('请选择手柄。仅接收 Input，不发送控制指令。');
