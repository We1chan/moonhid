import { descriptorFromCollections } from './browser-descriptor.js';
import { compareCollections, inputWireHex } from './hid-live.js';
import { inspect_descriptor, decode_wire } from './moonhid-core.js';

const $ = id => document.getElementById(id);
let device = null, record = null, total = 0;
const status = message => { $('capture-status').textContent = message; };
function input(event) {
  try {
    const wire = inputWireHex(event.reportId, event.data);
    const decoded = JSON.parse(decode_wire(record.reference_descriptor_hex, 'input', wire));
    total++;
    record.reports.push({ sequence: total, report_id: event.reportId, wire_hex: wire, result: decoded });
    if (record.reports.length > 100) record.reports.shift();
    record.total_received = total;
    $('capture-last').textContent = JSON.stringify(record.reports.at(-1), null, 2);
    $('capture-export').disabled = false;
    status(`${device.productName || 'HID 手柄'} · 已收到 ${total} 条报告；保留最近 ${record.reports.length} 条。${record.raw_values_mode ? ' 按位宽查看原始值。' : ''}`);
  } catch (error) { status(`报告处理失败：${error.message}`); }
}
async function stop() {
  const current = device;
  device = null;
  if (current) { current.removeEventListener('inputreport', input); if (current.opened) await current.close(); }
  $('capture-stop').disabled = true;
  $('capture-connect').disabled = false;
  $('capture-raw').disabled = false;
  $('capture-model').disabled = false;
  if (record) $('capture-record').value = JSON.stringify(record, null, 2);
}
$('capture-connect').addEventListener('click', async () => {
  $('capture-connect').disabled = true;
  $('capture-raw').disabled = true;
  $('capture-model').disabled = true;
  let candidate;
  try {
    [candidate] = await navigator.hid.requestDevice({ filters: [{ usagePage: 1, usage: 5 }, { usagePage: 1, usage: 4 }] });
    if (!candidate) { await stop(); return status('没有选择手柄。'); }
    const rawValues = $('capture-raw').checked;
    const reference = descriptorFromCollections(candidate.collections, { rawValues });
    const inspected = JSON.parse(inspect_descriptor(reference));
    if (!inspected.ok) throw new Error(`${inspected.error.code} @${inspected.error.offset}: ${inspected.error.message}`);
    if (!candidate.opened) await candidate.open();
    device = candidate; total = 0;
    record = { schema_version: 1, captured_at: new Date().toISOString(), descriptor_source: rawValues ? 'webhid-bit-layout-raw-values' : 'webhid-visible-fields-reconstruction',
      limitations: `Reference layout only; not the original USB/BLE descriptor. No original item encodings, nested collection or physical/local metadata verification.${rawValues ? ' Uses representable bit ranges; original logical ranges, Array and Null semantics are unverified.' : ''}`,
      device: { declared_model: $('capture-model').value, product_name: device.productName, vendor_id: device.vendorId, product_id: device.productId },
      raw_values_mode: rawValues, browser_collections: candidate.collections,
      reference_descriptor_hex: reference, descriptor: inspected.descriptor,
      collections_comparison: compareCollections(inspected.descriptor.layout, device.collections), total_received: 0, reports: [] };
    $('capture-descriptor').value = reference;
    $('capture-record').value = '';
    $('capture-last').textContent = '等待实际 Input 报告';
    $('capture-export').disabled = true;
    $('capture-stop').disabled = false;
    device.addEventListener('inputreport', input);
    status(`${device.productName || 'HID 手柄'} 已连接，请按 A 并移动摇杆。${rawValues ? '当前仅查看原始数值，不验证原始逻辑范围、Array 或 Null 语义。' : ''}`);
  } catch (error) {
    if (candidate?.opened && candidate !== device) await candidate.close().catch(() => {});
    $('capture-connect').disabled = false;
    $('capture-raw').disabled = false;
    $('capture-model').disabled = false;
    status(`连接失败：${error.message}`);
  }
});
$('capture-stop').addEventListener('click', async () => { try { await stop(); status(`已停止接收，保留 ${record?.reports.length ?? 0} 条报告。`); } catch (error) { status(`关闭失败：${error.message}`); } });
$('capture-export').addEventListener('click', () => {
  const url = URL.createObjectURL(new Blob([JSON.stringify(record, null, 2) + '\n'], { type: 'application/json' }));
  const link = document.createElement('a'); link.href = url; link.download = 'moonhid-device-validation.json'; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
});
navigator.hid?.addEventListener('disconnect', event => { if (event.device === device) { void stop().then(() => status('手柄已断开，记录保留。'), error => status(`手柄已断开：${error.message}`)); } });
window.addEventListener('pagehide', () => { void stop().catch(() => {}); });
if (!navigator.hid || !isSecureContext) { $('capture-connect').disabled = true; status('WebHID 不可用，请使用 Chromium、HTTPS 或 localhost。'); }
else status('请选择手柄。仅接收 Input，不发送控制指令。');
