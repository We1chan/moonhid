// Reconstructs a *reference* descriptor from browser-visible, flattened fields.
// It cannot recover original item encodings, nested collections or local metadata.
export function descriptorFromCollections(collections, { rawValues = false } = {}) {
  const ids = collections.flatMap(c => ['input', 'output', 'feature'].flatMap(k => (c[k + 'Reports'] ?? []).map(r => r.reportId)));
  if (ids.includes(0) && ids.some(id => id !== 0)) throw new Error('可见结构混用未编号和编号报告，当前参考描述符重建不支持');
  const bytes = [];
  function item(prefix, value, signed = false, forcedWidth = null) {
    if (!Number.isInteger(value) || value < -2147483648 || value > 4294967295) throw new RangeError('浏览器字段数值不在 HID 短项范围内');
    if (forcedWidth !== null && (value < 0 || value >= 2 ** (forcedWidth * 8))) throw new RangeError(`浏览器字段数值不在 0..${2 ** (forcedWidth * 8) - 1} 范围内`);
    const width = forcedWidth ?? (signed ? (value >= -128 && value <= 127 ? 1 : value >= -32768 && value <= 32767 ? 2 : 4)
      : value <= 127 ? 1 : value <= 32767 ? 2 : 4);
    bytes.push(prefix | (width === 4 ? 3 : width));
    for (let i = 0; i < width; i++) bytes.push((value >>> (i * 8)) & 255);
  }
  function usages(field) {
    // WebHID packs the page into every Usage, including page zero.
    if (field.isRange) { item(0x18, field.usageMinimum >>> 0, false, 4); item(0x28, field.usageMaximum >>> 0, false, 4); }
    else {
      const list = field.usages ?? [];
      for (let i = 0; i < list.length; i++) {
        let end = i;
        while (end + 1 < list.length && (list[end + 1] >>> 0) === (list[end] >>> 0) + 1 && (list[end + 1] >>> 16) === (list[i] >>> 16)) end++;
        if (end > i) { item(0x18, list[i] >>> 0, false, 4); item(0x28, list[end] >>> 0, false, 4); }
        else item(0x08, list[i] >>> 0, false, 4);
        i = end;
      }
    }
  }
  for (const collection of collections) {
    // These are separate 16-bit values; a four-byte Usage would carry its own page.
    item(0x04, collection.usagePage, false, 2); item(0x08, collection.usage, false, 2); item(0xa0, collection.type ?? 1, false, 1);
    for (const [kind, prefix] of [['input', 0x80], ['output', 0x90], ['feature', 0xb0]]) {
      for (const report of collection[kind + 'Reports'] ?? []) {
        if (report.reportId !== 0) item(0x84, report.reportId, false, 1);
        for (const field of report.items) {
          if (!rawValues && !field.isConstant && field.logicalMaximum < field.logicalMinimum) throw new Error('浏览器逻辑范围不完整；提供原始描述符，或明确选择按位宽查看原始值');
          const minimum = rawValues ? (field.logicalMinimum < 0 && field.reportSize <= 32 ? -(2 ** (field.reportSize - 1)) : 0) : field.logicalMinimum;
          const maximum = rawValues ? (field.reportSize <= 32 ? 2 ** (field.reportSize - (minimum < 0 ? 1 : 0)) - 1 : 0) : field.logicalMaximum;
          item(0x14, minimum, true);
          item(0x24, maximum, minimum < 0);
          item(0x74, field.reportSize); item(0x94, field.reportCount);
          if (!rawValues || !field.isArray) usages(field);
          const flags = Number(field.isConstant) | (rawValues || !field.isArray ? 2 : 0) | (!field.isAbsolute ? 4 : 0) |
            (field.wrap ? 8 : 0) | (!field.isLinear ? 16 : 0) | (!field.hasPreferredState ? 32 : 0) |
            (!rawValues && field.hasNull ? 64 : 0) | (field.isVolatile ? 128 : 0) | (field.isBufferedBytes ? 256 : 0);
          item(prefix, flags);
        }
      }
    }
    bytes.push(0xc0);
  }
  return bytes.map(b => b.toString(16).padStart(2, '0')).join(' ');
}
