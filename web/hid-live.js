// WebHID transport and browser metadata only; report decoding stays in MoonBit.
export function inputWireHex(reportId, data) {
  if (!Number.isInteger(reportId) || reportId < 0 || reportId > 255 || !(data instanceof DataView)) throw new TypeError('无效的 WebHID Input 事件');
  if (data.byteLength > 8192) throw new RangeError('报告载荷超过 8192 字节');
  const payload = new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
  const bytes = reportId ? [reportId, ...payload] : [...payload];
  return bytes.map(b => b.toString(16).padStart(2, '0')).join(' ');
}

function itemFlags(item) {
  return Number(item.isConstant) | (!item.isArray ? 2 : 0) | (!item.isAbsolute ? 4 : 0) |
    (item.wrap ? 8 : 0) | (!item.isLinear ? 16 : 0) | (!item.hasPreferredState ? 32 : 0) |
    (item.hasNull ? 64 : 0) | (item.isVolatile ? 128 : 0) | (item.isBufferedBytes ? 256 : 0);
}

function itemUsages(item) {
  if (item.isRange) {
    const min = item.usageMinimum >>> 0;
    const max = item.usageMaximum >>> 0;
    return [{ page: min >>> 16, min: min & 65535, max: max & 65535 }];
  }
  return (item.usages ?? []).map(usage => ({ page: usage >>> 16, min: usage & 65535, max: usage & 65535 }));
}

function sameUsages(left, right) {
  let i = 0, j = 0, a = 0, b = 0;
  while (i < left.length && j < right.length) {
    const x = left[i], y = right[j];
    if (x.page !== y.page || x.min + a !== y.min + b) return false;
    const count = Math.min(x.max - x.min + 1 - a, y.max - y.min + 1 - b);
    if (count <= 0) return false;
    a += count; b += count;
    if (x.min + a > x.max) { i++; a = 0; }
    if (y.min + b > y.max) { j++; b = 0; }
  }
  return i === left.length && j === right.length;
}

export function compareCollections(layout, collections) {
  const browser = new Map();
  function collect(nodes) {
    for (const collection of nodes) {
      for (const kind of ['input', 'output', 'feature']) {
        for (const report of collection[`${kind}Reports`] ?? []) {
          const key = `${kind}:${report.reportId}`;
          if (!browser.has(key)) browser.set(key, []);
          browser.get(key).push(...report.items);
        }
      }
      // WebHID top-level report lists already flatten nested collections.
    }
  }
  collect(collections);
  const differences = [];
  let comparedFields = 0;
  for (const report of layout.reports) {
    const key = `${report.kind}:${report.report_id}`;
    const actual = browser.get(key);
    if (!actual) { differences.push(`${key}：浏览器未暴露，可能是受保护 Collection 或描述符不匹配`); continue; }
    const expected = layout.fields.filter(f => f.kind === report.kind && f.report_id === report.report_id);
    const bits = actual.reduce((n, item) => n + item.reportSize * item.reportCount, 0);
    if (bits !== report.payload_bits) differences.push(`${key}：载荷位数 MoonHID=${report.payload_bits}，WebHID=${bits}`);
    if (expected.length !== actual.length) differences.push(`${key}：Main 字段数 MoonHID=${expected.length}，WebHID=${actual.length}`);
    for (let i = 0; i < Math.min(expected.length, actual.length); i++) {
      const field = expected[i], item = actual[i];
      const mismatches = [];
      if (field.bit_size !== item.reportSize) mismatches.push('size');
      if (field.count !== item.reportCount) mismatches.push('count');
      if (field.flags !== itemFlags(item)) mismatches.push('flags');
      if (field.logical_min !== item.logicalMinimum || field.logical_max !== item.logicalMaximum) mismatches.push('Logical');
      if (!sameUsages(field.usage_spans, itemUsages(item))) mismatches.push('Usage');
      if (mismatches.length) differences.push(`${key} 字段 ${i}：${mismatches.join(' / ')} 不同`);
      comparedFields++;
    }
    browser.delete(key);
  }
  for (const key of browser.keys()) differences.push(`${key}：粘贴的描述符中没有此报告`);
  return { comparedFields, differences };
}

export function createHIDController(hid, { onState, onReport, filters = [], beforeOpen }) {
  let device = null;
  let generation = 0;
  let busy = false;
  let received = 0;
  let closing = null;
  let disposed = false;
  const notify = (status, error = null) => onState({ status, error, device, busy, received });
  const input = event => {
    if (event.device !== device) return;
    received++;
    try { onReport({ device, reportId: event.reportId, wireHex: inputWireHex(event.reportId, event.data), received }); }
    catch (error) { notify('error', error.message); }
  };
  const unplugged = event => {
    if (event.device !== device) return;
    generation++;
    device.removeEventListener('inputreport', input);
    device = null; busy = false;
    notify('unplugged');
  };
  hid?.addEventListener('disconnect', unplugged);
  return {
    get device() { return device; },
    get busy() { return busy; },
    async connect() {
      if (!hid || busy || device || disposed) return;
      const current = ++generation;
      busy = true; notify('connecting');
      let candidate;
      let cancellationError = null;
      try {
        [candidate] = await hid.requestDevice({ filters });
        if (current !== generation) return;
        if (!candidate) { busy = false; notify('cancelled'); return; }
        if (beforeOpen) {
          await beforeOpen(candidate);
          if (current !== generation) return;
        }
        if (!candidate.opened) await candidate.open();
        if (current !== generation) {
          try { if (candidate.opened) await candidate.close(); }
          catch (error) { cancellationError = `关闭连接失败：${error.message}`; }
          return;
        }
        device = candidate; received = 0; busy = false;
        device.addEventListener('inputreport', input);
        notify('connected');
      } catch (error) {
        if (candidate?.opened && candidate !== device) await candidate.close().catch(() => {});
        if (current === generation) { busy = false; notify('error', error.message); }
      } finally {
        // Cancellation keeps the lock until the pending open and its cleanup finish.
        if (current !== generation && !device && !closing) {
          busy = false;
          notify(cancellationError ? 'error' : 'disconnected', cancellationError);
        }
      }
    },
    async disconnect() {
      if (closing) return closing;
      generation++;
      const current = device;
      device = null;
      if (current) current.removeEventListener('inputreport', input);
      if (!current) {
        // A cancelled connect still owns the lock until its finally block runs.
        notify(busy ? 'disconnecting' : 'disconnected');
        return;
      }
      busy = true;
      closing = Promise.resolve().then(async () => {
        let failure = null;
        try { if (current.opened) await current.close(); }
        catch (error) { failure = `关闭连接失败：${error.message}`; }
        finally { closing = null; busy = false; }
        notify(failure ? 'error' : 'disconnected', failure);
      });
      notify('disconnecting');
      return closing;
    },
    async dispose() {
      disposed = true;
      hid?.removeEventListener('disconnect', unplugged);
      await this.disconnect();
    },
  };
}
