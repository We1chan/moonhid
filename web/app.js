const $ = id => document.getElementById(id);
const MAX_TEXT = 393216;
const VALUE_PAGE = 200;
const ITEM_PAGE = 500;
const BITMAP_BYTES = 256;
const COLLECTION_LIMIT = 500;

const kindNames = { input: 'Input', output: 'Output', feature: 'Feature' };
const kindZh = { input: '输入', output: '输出', feature: '特性' };
const fixtureNames = { mouse: '鼠标', keyboard: '键盘', gamepad: '手柄' };
const stageLabels = { descriptor_hex: '描述符文本', descriptor: '描述符', report_hex: '报告文本', report: '报告' };
const collectionTypes = ['Physical', 'Application', 'Logical', 'Report', 'Named Array', 'Usage Switch', 'Usage Modifier'];
const unitSystems = ['None', 'SI Linear', 'SI Rotation', 'English Linear', 'English Rotation'];
const unitSymbols = [null, ['cm', 'g', 's', 'K', 'A', 'cd'], ['rad', 'g', 's', 'K', 'A', 'cd'], ['in', 'slug', 's', '°F', 'A', 'cd'], ['deg', 'slug', 's', '°F', 'A', 'cd']];
const unitDimensions = ['length', 'mass', 'time', 'temperature', 'current', 'luminous_intensity'];
const dimensionLetters = ['L', 'M', 'T', 'Θ', 'I', 'J'];
const mainTags = { 8: 'Input', 9: 'Output', 10: 'Collection', 11: 'Feature', 12: 'End Collection' };
const globalTags = ['Usage Page', 'Logical Minimum', 'Logical Maximum', 'Physical Minimum', 'Physical Maximum', 'Unit Exponent', 'Unit', 'Report Size', 'Report ID', 'Report Count', 'Push', 'Pop'];
const localTags = { 0: 'Usage', 1: 'Usage Minimum', 2: 'Usage Maximum', 3: 'Designator Index', 4: 'Designator Minimum', 5: 'Designator Maximum', 7: 'String Index', 8: 'String Minimum', 9: 'String Maximum', 10: 'Delimiter' };
const typeNames = ['main', 'global', 'local', 'reserved'];

// Common Usages only; everything else falls back to page + id.
const usagePages = { 0x01: 'Generic Desktop', 0x02: 'Simulation', 0x03: 'VR', 0x04: 'Sport', 0x05: 'Game', 0x06: 'Generic Device', 0x07: 'Keyboard', 0x08: 'LED', 0x09: 'Button', 0x0a: 'Ordinal', 0x0b: 'Telephony', 0x0c: 'Consumer', 0x0d: 'Digitizer', 0x0e: 'Haptics', 0x0f: 'PID', 0x10: 'Unicode', 0x14: 'Auxiliary Display', 0x20: 'Sensors', 0x40: 'Medical', 0x41: 'Braille', 0x59: 'Lighting', 0x80: 'Monitor', 0x84: 'Power', 0x85: 'Battery', 0x8c: 'Barcode Scanner', 0x8d: 'Scale', 0x90: 'Camera Control', 0x91: 'Arcade', 0xf1d0: 'FIDO' };
const genericUsages = { 0x01: 'Pointer', 0x02: 'Mouse', 0x04: 'Joystick', 0x05: 'Game Pad', 0x06: 'Keyboard', 0x07: 'Keypad', 0x08: 'Multi-axis Controller', 0x30: 'X', 0x31: 'Y', 0x32: 'Z', 0x33: 'Rx', 0x34: 'Ry', 0x35: 'Rz', 0x36: 'Slider', 0x37: 'Dial', 0x38: 'Wheel', 0x39: 'Hat Switch', 0x80: 'System Control', 0x81: 'System Power Down', 0x82: 'System Sleep', 0x83: 'System Wake Up' };
const consumerUsages = { 0x01: 'Consumer Control', 0x30: 'Power', 0xb5: 'Next Track', 0xb6: 'Previous Track', 0xb7: 'Stop', 0xcd: 'Play/Pause', 0xe2: 'Mute', 0xe9: 'Volume Up', 0xea: 'Volume Down', 0x238: 'AC Pan' };
const keyNames = { 0: 'No Event', 1: 'Error Roll Over', 40: 'Enter', 41: 'Escape', 42: 'Backspace', 43: 'Tab', 44: 'Space', 45: '-', 46: '=', 47: '[', 48: ']', 49: '\\', 51: ';', 52: "'", 53: '`', 54: ',', 55: '.', 56: '/', 57: 'Caps Lock', 79: 'Right Arrow', 80: 'Left Arrow', 81: 'Down Arrow', 82: 'Up Arrow' };
const modifierNames = ['Left Ctrl', 'Left Shift', 'Left Alt', 'Left GUI', 'Right Ctrl', 'Right Shift', 'Right Alt', 'Right GUI'];
const modifierShort = ['LCtrl', 'LShift', 'LAlt', 'LGUI', 'RCtrl', 'RShift', 'RAlt', 'RGUI'];
const ledNames = [null, 'Num Lock', 'Caps Lock', 'Scroll Lock', 'Compose', 'Kana'];
const ledShort = [null, 'Num', 'Caps', 'Scroll', 'Comp', 'Kana'];
const diagnosticText = {
  invalid_hex: '这里不是十六进制数字', odd_hex: '最后一个字节只有一位数字', split_byte: '空白把一个字节拆开了',
  text_limit: '十六进制文本过长', truncated_item: 'Item 数据被截断', value_size: 'Item 数据长度不受支持',
  unsupported_item: '不支持长 Item 或保留 Item', unsupported_main: '未知的 Main Item', unsupported_global: '不支持的 Global Item',
  unsupported_local: '不支持的 Local Item', usage_page: 'Usage Page 超过 16 位', usage_range: 'Usage 范围无效', usage_limit: 'Usage 数量超出上限',
  logical_range: 'Logical 范围无效或超出 Report Size', report_size: 'Report Size 超出 1..32', report_count: 'Report Count 超出 1..1024',
  report_id: 'Report ID 必须是 1..255', mixed_report_ids: '有的报告带 Report ID，有的没有', global_stack: 'Push / Pop 不配对',
  collection: 'Collection 不配对或嵌套过深', dangling_local: 'Local Item 之后缺少 Main Item', missing_dimensions: 'Main Item 之前缺少 Report Size 或 Report Count',
  main_flags: '不支持的 Main 标志', buffered_bytes: '不支持 Buffered Bytes', unit_exponent: 'Unit Exponent 超出 -8..7', unit_range: 'Unit 超过 32 位', field_limit: '字段数量超出上限',
  report_limit: '报告超过 65536 位', descriptor_limit: '描述符超过 65536 字节', empty_layout: '描述符中没有报告字段', invalid_layout: '布局超出支持范围',
  report_length: '报告长度与布局不符', short_report: '报告缺少所需的位', unknown_report: '布局中没有这个报告', bit_range: '位范围无效',
  report_kind: '报告方向无效', report_id_selection: 'Report ID 与所选报告不一致',
};

let core = null;
let fixtures = [];
const state = {
  fixture: null,
  descriptor: null,
  descriptorError: null,
  info: null,
  reportKey: null,
  drafts: new Map(),
  decoded: null,
  wireHex: null,
  reportError: null,
  reportIdSwitch: null,
  selected: null,
  focus: null,
  version: 0,
  itemPage: 0,
  valuePage: 0,
};

function h(tag, attrs, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs ?? {})) {
    if (value === null || value === undefined || value === false) continue;
    if (key === 'class') node.className = value;
    else if (key === 'dataset') Object.assign(node.dataset, value);
    else if (key === 'style') node.style.cssText = value;
    else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
    else node.setAttribute(key, value === true ? '' : value);
  }
  for (const child of children.flat()) {
    if (child !== null && child !== undefined && child !== false) node.append(typeof child === 'object' ? child : String(child));
  }
  return node;
}
const empty = text => h('p', { class: 'empty' }, text);
const hex = (n, width = 2) => n.toString(16).padStart(width, '0');
const superscript = n => String(n).replace(/[-0-9]/g, c => '⁻⁰¹²³⁴⁵⁶⁷⁸⁹'['-0123456789'.indexOf(c)]);
const plural = (n, unit) => `${n.toLocaleString('zh-CN')} ${unit}`;
function debounce(fn, ms) {
  let timer = 0;
  const run = () => { clearTimeout(timer); fn(); };
  const call = () => { clearTimeout(timer); timer = setTimeout(fn, ms); };
  call.now = run;
  return call;
}

// ---------- Usage names ----------
function pageName(page) {
  if (page >= 0xff00) return `Vendor 0x${hex(page, 4)}`;
  return usagePages[page] ?? `Page 0x${hex(page, 2)}`;
}
function usageName(usage) {
  if (!usage) return null;
  const { page, id } = usage;
  if (page === 0x01 && genericUsages[id]) return genericUsages[id];
  if (page === 0x09) return id === 0 ? 'No Button' : `Button ${id}`;
  if (page === 0x08 && ledNames[id]) return ledNames[id];
  if (page === 0x0c && consumerUsages[id]) return consumerUsages[id];
  if (page === 0x07) {
    if (id >= 4 && id <= 29) return `Key ${String.fromCharCode(61 + id)}`;
    if (id >= 30 && id <= 38) return `Key ${id - 29}`;
    if (id === 39) return 'Key 0';
    if (id >= 58 && id <= 69) return `F${id - 57}`;
    if (id >= 0xe0 && id <= 0xe7) return modifierNames[id - 0xe0];
    if (keyNames[id]) return keyNames[id];
  }
  if (page === 0x0a) return `Instance ${id}`;
  return `${pageName(page)} 0x${hex(id, 2)}`;
}
function usageShort(usage) {
  if (!usage) return null;
  const { page, id } = usage;
  if (page === 0x09 && id > 0) return `B${id}`;
  if (page === 0x08 && ledShort[id]) return ledShort[id];
  if (page === 0x07 && id >= 0xe0 && id <= 0xe7) return modifierShort[id - 0xe0];
  return usageName(usage);
}
const usageCode = usage => usage ? `${hex(usage.page, 4)}:${hex(usage.id, 4)}` : '';
function elementUsage(field, element) {
  if (field.flags & 1 || !(field.flags & 2) || !field.usages.length) return null;
  return field.usages[Math.min(element, field.usages.length - 1)];
}
function fieldSummary(field) {
  if (field.flags & 1) return `填充 · ${field.bit_size * field.count} bit`;
  const names = [...new Set(field.usages.map(usageName))];
  if (!(field.flags & 2)) {
    if (!names.length) return '数组 · 未声明 Usage';
    return names.length === 1 ? `数组 · ${names[0]}` : `数组 · ${names[0]} … ${names.at(-1)}（${field.usages.length} 个 Usage）`;
  }
  if (!names.length) return '未声明 Usage';
  return names.length <= 4 ? names.join(' / ') : `${names.slice(0, 3).join(' / ')} … ${names.at(-1)}`;
}

// ---------- Units and flags ----------
function unitText(unit, exponent = null) {
  if (!unit) return null;
  const symbols = unitSymbols[unit.system];
  const parts = unitDimensions.map((key, n) => unit[key] ? `${symbols ? symbols[n] : dimensionLetters[n]}${unit[key] === 1 ? '' : superscript(unit[key])}` : null).filter(Boolean);
  const scale = exponent ? `10${superscript(exponent)} ` : '';
  return parts.length ? scale + parts.join('·') : '无量纲';
}
function unitFromRaw(raw) {
  const nibble = shift => { const v = (raw >>> shift) & 0xf; return v >= 8 ? v - 16 : v; };
  return { raw, system: raw & 0xf, length: nibble(4), mass: nibble(8), time: nibble(12), temperature: nibble(16), current: nibble(20), luminous_intensity: nibble(24) };
}
const systemName = system => unitSystems[system] ?? `保留系统 ${system}`;
function mainFlagNames(tag, value) {
  const names = [value & 1 ? 'Cnst' : 'Data', value & 2 ? 'Var' : 'Arr', value & 4 ? 'Rel' : 'Abs'];
  for (const [bit, name] of [[8, 'Wrap'], [16, 'NLin'], [32, 'NPrf'], [64, 'Null'], [256, 'Buf']]) if (value & bit) names.push(name);
  if (tag !== 8 && value & 128) names.push('Vol');
  return names;
}
function fieldFlags(field) {
  const names = [field.flags & 1 ? 'Constant' : 'Data', field.flags & 2 ? 'Variable' : 'Array', field.flags & 4 ? 'Relative' : 'Absolute'];
  for (const [bit, name] of [[8, 'Wrap'], [16, 'Nonlinear'], [32, 'No Preferred'], [64, 'Null State']]) if (field.flags & bit) names.push(name);
  if (field.kind !== 'input' && field.flags & 128) names.push('Volatile');
  return names;
}

// ---------- Descriptor items ----------
// Mirrors layout.mbt: maxima read unsigned unless the matching minimum is negative.
function annotate(descriptor) {
  const bytes = descriptor.descriptor_hex ? descriptor.descriptor_hex.split(' ') : [];
  const fieldByOffset = new Map(descriptor.layout.fields.map((field, index) => [field.descriptor_offset, index]));
  let global = { page: 0, logicalMin: 0, physicalMin: null };
  const stack = [];
  let depth = 0;
  const items = descriptor.items.map((item, index) => {
    const end = index + 1 < descriptor.items.length ? descriptor.items[index + 1].offset : descriptor.byte_length;
    const data = item.data_hex ? item.data_hex.replace(/\s+/g, '').match(/../g).map(b => parseInt(b, 16)) : [];
    const unsigned = data.reduce((sum, byte, n) => sum + byte * 2 ** (8 * n), 0);
    const signed = data.length && data.at(-1) & 0x80 ? unsigned - 2 ** (8 * data.length) : unsigned;
    const usage = () => data.length === 4 ? { page: unsigned >>> 16, id: unsigned & 0xffff } : { page: global.page, id: unsigned };
    let name, value = null, title = null, rowDepth = depth;
    if (item.is_long) name = 'Long Item';
    else if (item.type_code === 0) {
      name = mainTags[item.tag] ?? `Main ${item.tag}`;
      if (item.tag === 8 || item.tag === 9 || item.tag === 11) value = mainFlagNames(item.tag, unsigned).join(', ');
      else if (item.tag === 10) { value = collectionTypes[unsigned] ?? (unsigned >= 0x80 ? `Vendor 0x${hex(unsigned)}` : `Reserved 0x${hex(unsigned)}`); depth++; }
      else if (item.tag === 12) rowDepth = depth = Math.max(0, depth - 1);
    } else if (item.type_code === 1) {
      name = globalTags[item.tag] ?? `Global ${item.tag}`;
      switch (item.tag) {
        case 0: global.page = unsigned; value = pageName(unsigned); title = `0x${hex(unsigned, 4)}`; break;
        case 1: global.logicalMin = signed; value = signed; break;
        case 2: value = global.logicalMin < 0 ? signed : unsigned; break;
        case 3: global.physicalMin = signed; value = signed; break;
        case 4: value = global.physicalMin !== null && global.physicalMin < 0 ? signed : unsigned; break;
        case 5: value = unsigned <= 15 ? (unsigned >= 8 ? unsigned - 16 : unsigned) : signed; break;
        case 6: { const unit = unitFromRaw(unsigned); value = `${systemName(unit.system)} · ${unitText(unit)}`; title = `0x${hex(unsigned)}`; break; }
        case 10: stack.push({ ...global }); break;
        case 11: global = stack.pop() ?? global; break;
        default: value = unsigned;
      }
    } else if (item.type_code === 2) {
      name = localTags[item.tag] ?? `Local ${item.tag}`;
      if (item.tag <= 2) { const u = usage(); value = usageName(u); title = usageCode(u); }
      else value = unsigned;
    } else name = `Reserved ${item.tag}`;
    return { ...item, index, end, bytes: bytes.slice(item.offset, end).join(' '), depth: rowDepth, type: item.is_long ? 'reserved' : typeNames[item.type_code], name, value, title, field: fieldByOffset.get(item.offset) };
  });
  return { items, itemByOffset: new Map(items.map(item => [item.offset, item.index])) };
}

// ---------- Hex editors with painted marks ----------
class HexEditor {
  constructor(textarea) {
    this.input = textarea;
    this.backdrop = textarea.parentElement.querySelector('.editor-backdrop');
    this.marks = [];
    this.spanText = null;
    this.spans = [];
    textarea.addEventListener('scroll', () => this.sync());
    new ResizeObserver(() => this.sync()).observe(textarea);
  }
  get value() { return this.input.value; }
  set value(text) { this.input.value = text; this.input.scrollTop = 0; this.setMarks([]); }
  // Character range of bytes [start, end); hex pairs are always adjacent (see parse_hex).
  byteRange(start, end) {
    if (this.spanText !== this.input.value) {
      const text = this.input.value, spans = [];
      for (let i = 0, open = -1; i < text.length; i++) {
        const c = text.charCodeAt(i);
        if (c === 32 || c === 9 || c === 10 || c === 13) continue;
        if (open < 0) open = i; else { spans.push([open, i + 1]); open = -1; }
      }
      this.spanText = text;
      this.spans = spans;
    }
    if (start >= this.spans.length || end <= start) return null;
    return [this.spans[start][0], this.spans[Math.min(end, this.spans.length) - 1][1]];
  }
  errorRange(result) {
    const text = this.input.value;
    if (!text.length) return null;
    if (result.stage.endsWith('_hex')) {
      const start = Math.min(result.error.offset, text.length - 1);
      return [start, start + 1];
    }
    this.byteRange(0, 1);
    if (!this.spans.length) return null;
    const at = Math.min(result.error.offset, this.spans.length - 1);
    return this.byteRange(at, at + 1);
  }
  setMarks(marks, reveal = false) {
    this.marks = marks.filter(Boolean).sort((a, b) => a.start - b.start);
    const text = this.input.value;
    if (!this.marks.length) { this.backdrop.replaceChildren(); return; }
    const parts = [];
    let cursor = 0;
    for (const mark of this.marks) {
      if (mark.start < cursor) continue;
      parts.push(text.slice(cursor, mark.start), h('mark', { class: mark.tone }, text.slice(mark.start, mark.end)));
      cursor = mark.end;
    }
    parts.push(text.slice(cursor) + '\n');
    this.backdrop.replaceChildren(...parts);
    if (reveal) {
      const first = this.backdrop.querySelector('mark');
      const top = first.offsetTop, view = this.input.clientHeight;
      if (top < this.input.scrollTop || top + first.offsetHeight > this.input.scrollTop + view) this.input.scrollTop = Math.max(0, top - view / 3);
    }
    this.sync();
  }
  select([start, end]) {
    this.input.focus();
    this.input.setSelectionRange(start, end);
  }
  sync() {
    this.backdrop.scrollTop = this.input.scrollTop;
    this.backdrop.scrollLeft = this.input.scrollLeft;
  }
}
const descriptorEditor = new HexEditor($('descriptor'));
const reportEditor = new HexEditor($('report'));

// ---------- Derived state ----------
const reportKey = report => `${report.kind}:${report.report_id}`;
function currentReport() {
  return state.descriptor?.layout.reports.find(report => reportKey(report) === state.reportKey) ?? null;
}
function reportFields() {
  const report = currentReport();
  if (!report) return [];
  return state.descriptor.layout.fields.map((field, index) => ({ field, index })).filter(({ field }) => field.kind === report.kind && field.report_id === report.report_id);
}
let colorCache = { key: null, colors: new Map() };
function colorOf(index) {
  const key = `${state.version}|${state.reportKey}`;
  if (colorCache.key !== key) {
    const colors = new Map();
    let n = 0;
    for (const { field, index: i } of reportFields()) if (!(field.flags & 1)) colors.set(i, n++ % 8);
    colorCache = { key, colors };
  }
  return colorCache.colors.get(index);
}
const colorClass = index => { const c = colorOf(index); return c === undefined ? '' : `c${c}`; };
const prefixBytes = () => state.descriptor?.layout.has_report_ids ? 1 : 0;
function fieldBits(field) { return { start: field.bit_offset, end: field.bit_offset + field.bit_size * field.count - 1 }; }
function wireBytesOf(field) {
  const { start, end } = fieldBits(field);
  return { first: prefixBytes() + Math.floor(start / 8), last: prefixBytes() + Math.floor(Math.max(start, end) / 8) };
}
function firstField() {
  const fields = reportFields();
  return (fields.find(({ field }) => !(field.flags & 1)) ?? fields[0])?.index ?? null;
}
function sampleFor(report) {
  if (!state.fixture || !report) return null;
  if (report.kind === 'input') return state.fixture.input_hex;
  if (report.kind === 'output') return state.fixture.output_hex ?? null;
  return null;
}

// ---------- Parsing and decoding ----------
function guard(text, stage) {
  return text.length > MAX_TEXT ? { ok: false, stage, error: { offset: MAX_TEXT, code: 'text_limit', message: `Hex text exceeds ${MAX_TEXT} characters` } } : null;
}
function parseDescriptor() {
  const text = descriptorEditor.value;
  if (!text.trim()) {
    Object.assign(state, { descriptor: null, info: null, descriptorError: null, decoded: null, wireHex: null, reportError: null, selected: null, focus: null });
    return renderAll();
  }
  const result = guard(text, 'descriptor_hex') ?? JSON.parse(core.inspect_descriptor(text));
  if (!result.ok) {
    Object.assign(state, { descriptor: null, info: null, descriptorError: result, decoded: null, wireHex: null, reportError: null, selected: null, focus: null });
    renderAll();
    paintDescriptor(true);
    return;
  }
  const previous = state.descriptor;
  state.descriptor = result.descriptor;
  state.descriptorError = null;
  state.version++;
  state.info = annotate(result.descriptor);
  state.focus = null;
  state.itemPage = 0;
  const reports = result.descriptor.layout.reports;
  if (state.fixture?.pending) {
    state.fixture.pending = false;
    state.drafts = new Map(reports.map(report => [reportKey(report), sampleFor(report)]).filter(([, sample]) => sample));
    state.reportKey = reportKey(reports.find(report => report.kind === 'input') ?? reports[0]);
  } else if (!reports.some(report => reportKey(report) === state.reportKey)) {
    state.reportKey = reportKey(reports[0]);
  }
  const keep = previous && state.selected !== null && reportFields().some(({ index }) => index === state.selected);
  if (!keep) state.selected = firstField();
  state.valuePage = 0;
  reportEditor.value = state.drafts.get(state.reportKey) ?? '';
  decodeReport(false);
  renderAll();
}
function decodeReport(render = true) {
  Object.assign(state, { decoded: null, wireHex: null, reportError: null, reportIdSwitch: null });
  const report = currentReport();
  const text = reportEditor.value;
  if (report && text.trim()) {
    const result = guard(text, 'report_hex') ?? JSON.parse(core.decode_wire(state.descriptor.descriptor_hex, report.kind, text));
    if (!result.ok) state.reportError = result;
    else if (result.decoded.report_id !== report.report_id) {
      state.reportError = { ok: false, stage: 'report', error: { offset: 0, code: 'report_id_selection', message: `First byte is Report ID ${result.decoded.report_id}, selected ID ${report.report_id}` } };
      const target = state.descriptor.layout.reports.find(r => r.kind === report.kind && r.report_id === result.decoded.report_id);
      if (target) state.reportIdSwitch = reportKey(target);
    } else {
      state.decoded = result.decoded;
      state.wireHex = result.wire_hex;
    }
  }
  if (render) { renderReportStatus(); renderBitmap(); renderValues(); paintReport(); renderExport(); }
}
const scheduleDescriptor = debounce(parseDescriptor, 180);
const scheduleReport = debounce(() => decodeReport(), 120);

// ---------- Selection ----------
function selectField(index, { fromItems = false } = {}) {
  const field = state.descriptor.layout.fields[index];
  const key = `${field.kind}:${field.report_id}`;
  state.selected = index;
  state.focus = null;
  if (key !== state.reportKey) return switchReport(key, index);
  applySelection({ list: !fromItems, hex: true });
}
function focusItem(index, reveal = false) {
  const item = state.info.items[index];
  if (item.field !== undefined) return selectField(item.field, { fromItems: !reveal });
  state.focus = { item: index, start: item.offset, end: item.end };
  applySelection({ hex: true });
}
function focusCollection(index) {
  const collection = state.descriptor.layout.collections[index];
  const open = state.info.itemByOffset.get(collection.descriptor_offset);
  const close = state.info.itemByOffset.get(collection.end_offset);
  state.focus = { item: open, collection: index, start: collection.descriptor_offset, end: state.info.items[close]?.end ?? collection.end_offset + 1 };
  applySelection({ list: true, hex: true });
}
function markFor(start, end, tone) {
  const range = descriptorEditor.byteRange(start, end);
  return range ? { start: range[0], end: range[1], tone } : null;
}
function applySelection({ list = false, hex: revealHex = false } = {}) {
  for (const node of document.querySelectorAll('#bitmap [data-field], #values [data-field]')) node.classList.toggle('on', Number(node.dataset.field) === state.selected);
  const focused = focusedItem();
  if (list && focused !== null && Math.floor(focused / ITEM_PAGE) !== state.itemPage) { state.itemPage = Math.floor(focused / ITEM_PAGE); renderItems(); }
  for (const node of $('items').querySelectorAll('[data-item]')) node.classList.toggle('focus', Number(node.dataset.item) === focused);
  for (const node of $('collections').querySelectorAll('[data-collection]')) node.classList.toggle('focus', Number(node.dataset.collection) === state.focus?.collection);
  if (list && focused !== null) {
    const row = $('items').querySelector(`[data-item="${focused}"]`);
    if (row) revealIn($('items'), row);
  }
  renderDetail();
  paintDescriptor(revealHex);
  paintReport();
}
function focusedItem() {
  if (!state.info) return null;
  if (state.focus) return state.focus.item ?? null;
  if (state.selected === null) return null;
  return state.info.itemByOffset.get(state.descriptor.layout.fields[state.selected].descriptor_offset) ?? null;
}
function revealIn(container, node) {
  const box = container.getBoundingClientRect(), rect = node.getBoundingClientRect();
  if (rect.top < box.top) container.scrollTop -= box.top - rect.top + 24;
  else if (rect.bottom > box.bottom) container.scrollTop += rect.bottom - box.bottom + 24;
}
function switchReport(key, select = null) {
  state.reportKey = key;
  state.selected = select ?? firstField();
  state.focus = null;
  state.valuePage = 0;
  reportEditor.value = state.drafts.get(key) ?? '';
  decodeReport(false);
  renderReports();
  renderReportStatus();
  renderBitmap();
  renderValues();
  renderItems();
  applySelection({ list: true, hex: true });
  renderExport();
}

// ---------- Rendering ----------
function renderAll() {
  renderFixtures();
  renderDescriptorStatus();
  renderItems();
  renderReports();
  renderReportStatus();
  renderBitmap();
  renderValues();
  renderCollections();
  renderExport();
  applySelection();
}
function renderFixtures() {
  for (const button of $('fixtures').querySelectorAll('button')) button.setAttribute('aria-pressed', String(button.dataset.fixture === state.fixture?.name));
}
function renderExport() { $('export').disabled = !state.descriptor; }
function diagnostic(result, locate) {
  const unit = result.stage.endsWith('_hex') ? '字符' : '字节';
  const text = h('span', { class: 'status-text' },
    `${diagnosticText[result.error.code] ?? '输入未通过检查'}`, ' ', h('code', null, result.error.code),
    h('span', { class: 'raw' }, `${stageLabels[result.stage] ?? result.stage}${unit}偏移 ${result.error.offset} · ${result.error.message}`));
  return [text, locate];
}
function setStatus(id, tone, ...children) {
  $(id).className = `status ${tone}`;
  $(id).replaceChildren(...children.flat());
}
function renderDescriptorStatus() {
  const d = state.descriptor;
  $('descriptor-meta').textContent = d ? plural(d.byte_length, '字节') : '';
  $('item-meta').textContent = d ? plural(d.items.length, '项') : '';
  if (state.descriptorError) {
    const locate = h('button', { type: 'button', class: 'link', onclick: () => { const range = descriptorEditor.errorRange(state.descriptorError); if (range) descriptorEditor.select(range); } }, '定位');
    return setStatus('descriptor-status', 'error', diagnostic(state.descriptorError, locate));
  }
  if (!d) return setStatus('descriptor-status', '', h('span', { class: 'status-text' }, core ? '粘贴报告描述符的十六进制字节，或选择一个样例。' : '正在加载 MoonBit 解析器…'));
  const layout = d.layout;
  setStatus('descriptor-status', 'ok', h('span', { class: 'status-text' }, `已解析 · ${plural(layout.fields.length, '个字段')} · ${plural(layout.reports.length, '个报告')} · ${plural(layout.collections.length, '个 Collection')}`));
}
function pager(page, total, size, onChange) {
  if (total <= size) return null;
  const pages = Math.ceil(total / size);
  return h('div', { class: 'pager' },
    h('button', { type: 'button', disabled: page === 0, onclick: () => onChange(page - 1) }, '上一页'),
    h('span', null, `${page * size + 1}–${Math.min(total, (page + 1) * size)} / ${total}`),
    h('button', { type: 'button', disabled: page + 1 >= pages, onclick: () => onChange(page + 1) }, '下一页'));
}
function renderItems() {
  const box = $('items');
  if (!state.info) return box.replaceChildren(empty(state.descriptorError ? '修正描述符后显示 Items。' : '解析后在这里逐项显示描述符。'));
  const items = state.info.items;
  const slice = items.slice(state.itemPage * ITEM_PAGE, (state.itemPage + 1) * ITEM_PAGE);
  const current = currentReport();
  const list = h('ol', null, slice.map(item => {
    let ref = null;
    if (item.field !== undefined) {
      const field = state.descriptor.layout.fields[item.field];
      const here = current && field.kind === current.kind && field.report_id === current.report_id;
      ref = h('span', { class: `item-ref ${here ? `here ${colorClass(item.field)}` : ''}`, title: here ? '当前报告中的字段' : `${kindNames[field.kind]} · ID ${field.report_id}` }, here ? `#${item.field}` : `${kindNames[field.kind]} #${item.field}`);
    }
    return h('li', null, h('button', { type: 'button', class: `item t-${item.type}`, dataset: { item: item.index }, onclick: () => focusItem(item.index) },
      h('span', { class: 'item-off' }, item.offset),
      h('span', { class: 'item-bytes' }, item.bytes),
      h('span', { class: 'item-body' },
        item.depth ? h('span', { class: 'indent', style: `--depth:${item.depth}` }) : null,
        h('span', { class: 'item-name' }, item.name),
        item.value !== null ? h('span', { class: 'item-value', title: item.title }, `${item.value}`) : null),
      ref));
  }));
  box.replaceChildren(list, pager(state.itemPage, items.length, ITEM_PAGE, page => { state.itemPage = page; renderItems(); box.scrollTop = 0; applySelection(); }) ?? '');
}
function renderReports() {
  const box = $('reports');
  if (!state.descriptor) {
    $('report-meta').textContent = '';
    $('report').disabled = true;
    return box.replaceChildren();
  }
  const reports = state.descriptor.layout.reports;
  $('report-meta').textContent = state.descriptor.layout.has_report_ids ? '使用 Report ID' : '无 Report ID 前缀';
  $('report').disabled = false;
  box.replaceChildren(...reports.map(report => h('button', {
    type: 'button', class: 'report-tab', 'aria-pressed': String(reportKey(report) === state.reportKey),
    title: `${kindZh[report.kind]}报告 · 载荷 ${report.payload_bits} 位 · 线上 ${report.wire_bytes} 字节`,
    onclick: () => { if (reportKey(report) !== state.reportKey) switchReport(reportKey(report)); },
  }, h('strong', null, kindNames[report.kind]), h('span', null, report.report_id ? `ID ${report.report_id}` : '无 ID'), h('span', null, `${report.wire_bytes} 字节`))));
}
function renderReportStatus() {
  const report = currentReport();
  const sample = sampleFor(report);
  $('sample-report').hidden = !sample || reportEditor.value.trim() === sample;
  if (!report) return setStatus('report-status', '', h('span', { class: 'status-text' }, state.descriptorError ? '描述符未通过检查。' : ''));
  if (state.reportError) {
    const action = state.reportIdSwitch
      ? h('button', { type: 'button', class: 'link', onclick: () => { const text = reportEditor.value; state.drafts.delete(state.reportKey); state.drafts.set(state.reportIdSwitch, text); switchReport(state.reportIdSwitch); } }, `切换到 ID ${state.reportIdSwitch.split(':')[1]}`)
      : h('button', { type: 'button', class: 'link', onclick: () => { const range = reportEditor.errorRange(state.reportError); if (range) reportEditor.select(range); } }, '定位');
    return setStatus('report-status', 'error', diagnostic(state.reportError, action));
  }
  if (!state.decoded) return setStatus('report-status', '', h('span', { class: 'status-text' }, `输入 ${report.wire_bytes} 个字节${state.descriptor.layout.has_report_ids ? `，首字节为 Report ID ${report.report_id}` : ''}。`));
  const values = state.decoded.values;
  const outside = values.filter(v => !v.in_logical_range && !v.is_null).length;
  const nulls = values.filter(v => v.is_null).length;
  const extra = [outside ? `${outside} 个越界` : null, nulls ? `${nulls} 个 Null State` : null].filter(Boolean).join('，');
  setStatus('report-status', outside ? 'warn' : 'ok', h('span', { class: 'status-text' }, `已解码 ${plural(values.length, '个值')}${extra ? ` · ${extra}` : ''}`));
}
function renderBitmap() {
  const box = $('bitmap');
  const report = currentReport();
  if (!report) return box.replaceChildren(empty('描述符通过检查后显示每个报告字节的位分配。'));
  const prefix = prefixBytes();
  const shown = Math.min(report.wire_bytes, BITMAP_BYTES);
  const limit = Math.max(0, (shown - prefix) * 8);
  const owner = new Array(limit).fill(null);
  for (const { field, index } of reportFields()) {
    for (let e = 0; e < field.count; e++) {
      const start = field.bit_offset + e * field.bit_size;
      if (start >= limit) break;
      const slot = { index, element: e, start, field };
      for (let b = 0; b < field.bit_size && start + b < limit; b++) owner[start + b] = slot;
    }
  }
  const wire = state.decoded && state.wireHex ? state.wireHex.split(' ').map(b => parseInt(b, 16)) : null;
  const decoded = new Map((state.decoded?.values ?? []).map(v => [`${v.field_index}:${v.element_index}`, v]));
  const rows = [h('div', { class: 'bm-row bm-head', 'aria-hidden': 'true' }, h('span', { class: 'bm-off' }, '字节'), h('div', { class: 'bm-bits' }, [7, 6, 5, 4, 3, 2, 1, 0].map(n => h('span', null, n))), h('span', { class: 'bm-hex' }, 'hex'))];
  const digits = (value, hi, lo) => {
    const out = [];
    for (let bit = hi; bit >= lo; bit--) {
      const v = value === null ? null : (value >> bit) & 1;
      out.push(h('span', { class: v === null ? 'zero' : v ? 'one' : 'zero' }, v === null ? '·' : v));
    }
    return h('span', { class: 'seg-bits' }, out);
  };
  for (let byte = 0; byte < shown; byte++) {
    const value = wire ? wire[byte] : null;
    let segments;
    if (prefix && byte === 0) {
      segments = [h('div', { class: 'seg rid', style: '--span:8', title: `Report ID 前缀 = ${report.report_id}` }, h('span', { class: 'seg-label' }, `Report ID ${report.report_id}`), digits(report.report_id, 7, 0))];
    } else {
      segments = [];
      const base = (byte - prefix) * 8;
      for (let hi = 7; hi >= 0;) {
        const slot = owner[base + hi];
        let lo = hi;
        while (lo > 0 && owner[base + lo - 1] === slot) lo--;
        const span = hi - lo + 1;
        const bits = `载荷位 ${base + lo}${span > 1 ? `–${base + hi}` : ''}`;
        if (!slot) {
          segments.push(h('div', { class: 'seg unused', style: `--span:${span}`, title: `${bits} · 未被字段使用` }, h('span', { class: 'seg-label' }, span > 2 ? '未用' : ''), digits(value, hi, lo)));
        } else {
          const { field, index, element, start } = slot;
          const pad = field.flags & 1;
          const usage = elementUsage(field, element);
          const full = pad ? '填充' : usage ? usageName(usage) : field.flags & 2 ? `#${index}[${element}]` : `数组[${element}]`;
          const label = span <= 2 && usage ? usageShort(usage) : full;
          const part = field.bit_size > span ? h('small', null, `[${base + hi - start}:${base + lo - start}]`) : null;
          const picked = !pad && !(field.flags & 2) ? decoded.get(`${index}:${element}`)?.usage : null;
          segments.push(h('button', {
            type: 'button', class: `seg ${pad ? 'pad' : colorClass(index)}${index === state.selected ? ' on' : ''}`, style: `--span:${span}`,
            dataset: { field: index }, title: `字段 #${index}${field.count > 1 ? `[${element}]` : ''} · ${full} · ${bits}`,
            onclick: () => selectField(index),
          }, h('span', { class: 'seg-label' }, label, part, picked ? h('small', null, `→ ${usageName(picked)}`) : null), digits(value, hi, lo)));
        }
        hi = lo - 1;
      }
    }
    rows.push(h('div', { class: 'bm-row' },
      h('span', { class: 'bm-off' }, prefix && byte === 0 ? 'ID' : byte),
      h('div', { class: 'bm-bits' }, segments),
      h('span', { class: `bm-hex${value === null && !(prefix && byte === 0) ? ' unknown' : ''}` }, value !== null ? hex(value) : prefix && byte === 0 ? hex(report.report_id) : '··')));
  }
  if (report.wire_bytes > shown) rows.push(h('p', { class: 'bm-more' }, `只显示前 ${shown} 个字节；完整 ${report.wire_bytes} 字节的解码值见下表与导出的 JSON。`));
  box.replaceChildren(...rows);
}
function renderValues() {
  const box = $('values');
  if (!currentReport()) { $('values-meta').textContent = ''; return box.replaceChildren(empty('描述符通过检查后列出字段。')); }
  const rows = [];
  for (const { field, index } of reportFields()) {
    if (field.flags & 1) rows.push({ field, index, pad: true });
    else for (let e = 0; e < field.count; e++) rows.push({ field, index, element: e });
  }
  const decoded = new Map((state.decoded?.values ?? []).map(v => [`${v.field_index}:${v.element_index}`, v]));
  const fields = reportFields();
  $('values-meta').textContent = `${plural(fields.length, '个字段')} · ${plural(rows.filter(r => !r.pad).length, '个元素')}`;
  const page = rows.slice(state.valuePage * VALUE_PAGE, (state.valuePage + 1) * VALUE_PAGE);
  const body = page.map(row => {
    const { field, index } = row;
    const ref = h('button', { type: 'button', class: 'field-ref', onclick: event => { event.stopPropagation(); selectField(index); } }, `#${index}`);
    if (row.pad) {
      const { start, end } = fieldBits(field);
      return h('tr', { class: `pad${index === state.selected ? ' on' : ''}`, dataset: { field: index }, onclick: () => selectField(index) },
        h('td', null, ref), h('td', { class: 'dim' }, `填充 · ${field.bit_size * field.count} bit`), h('td', { class: 'bits' }, `${start}–${end}`), h('td', { class: 'num dim' }, '—'), h('td', null, h('span', { class: 'tag' }, '不解码')));
    }
    const value = decoded.get(`${index}:${row.element}`);
    const usage = value ? value.usage : elementUsage(field, row.element);
    const start = field.bit_offset + row.element * field.bit_size;
    const isArray = !(field.flags & 2);
    const usageCell = usage
      ? h('span', { class: 'usage' }, h('span', null, usageName(usage)), h('span', { class: 'usage-code' }, usageCode(usage)))
      : h('span', { class: 'dim' }, isArray ? (value ? '未映射' : '数组元素') : '未声明');
    let tag;
    if (value?.is_null) tag = h('span', { class: 'tag warn' }, 'Null State');
    else if (value && !value.in_logical_range) tag = h('span', { class: 'tag bad' }, '越界');
    else tag = h('span', { class: 'dim' }, isArray ? '数组' : field.flags & 4 ? '相对' : '绝对');
    return h('tr', { class: `${colorClass(index)}${index === state.selected ? ' on' : ''}`, dataset: { field: index }, onclick: () => selectField(index) },
      h('td', null, ref, field.count > 1 ? h('span', { class: 'elem' }, ` [${row.element}]`) : null),
      h('td', null, usageCell),
      h('td', { class: 'bits' }, field.bit_size > 1 ? `${start}–${start + field.bit_size - 1}` : start),
      h('td', { class: `num${value ? '' : ' dim'}` }, value ? value.value : '—'),
      h('td', null, tag));
  });
  const table = h('table', null,
    h('thead', null, h('tr', null, h('th', null, '字段'), h('th', null, 'Usage'), h('th', null, '载荷位'), h('th', { class: 'num' }, '值'), h('th', null, '说明'))),
    h('tbody', null, body));
  box.replaceChildren(table, pager(state.valuePage, rows.length, VALUE_PAGE, p => { state.valuePage = p; renderValues(); }) ?? '');
}
function collectionPath(index) {
  const path = [];
  for (let depth = 0; index !== null && index !== undefined && depth < 64; depth++) {
    const collection = state.descriptor.layout.collections[index];
    path.unshift(`${usageName(collection.usage) ?? '未声明'}`);
    index = collection.parent_index;
  }
  return path;
}
function renderDetail() {
  const box = $('field-detail');
  if (!state.descriptor) return box.replaceChildren(empty('解析描述符后，选择位布局、字段表或 Items 中的字段。'));
  if (state.selected === null) return box.replaceChildren(empty('当前报告没有字段。'));
  const index = state.selected;
  const field = state.descriptor.layout.fields[index];
  const pad = field.flags & 1;
  const { start, end } = fieldBits(field);
  const { first, last } = wireBytesOf(field);
  const item = state.info.items[state.info.itemByOffset.get(field.descriptor_offset)];
  const declared = field.physical_min === null && field.physical_max === null;
  const facts = [
    ['位置', [`载荷位 ${start}–${end}`, h('span', { class: 'sub' }, `${field.bit_size} bit × ${field.count} = ${field.bit_size * field.count} bit · 报告字节 ${first === last ? first : `${first}–${last}`}`)]],
    ['标志', [h('span', { class: 'flags' }, fieldFlags(field).map(name => h('span', { class: 'flag' }, name))), h('span', { class: 'sub mono' }, `0x${hex(field.flags)}`)]],
    ['Logical', `${field.logical_min} … ${field.logical_max}`],
    ['Physical', declared ? ['未声明', h('span', { class: 'sub' }, `沿用 Logical：${field.effective_physical_min} … ${field.effective_physical_max}`)]
      : [`${field.physical_min ?? '未声明'} … ${field.physical_max ?? '未声明'}`, h('span', { class: 'sub' }, `有效范围 ${field.effective_physical_min} … ${field.effective_physical_max}`)]],
    ['单位', field.unit ? [unitText(field.unit, field.unit_exponent ?? 0), h('span', { class: 'sub' }, `${systemName(field.unit.system)} · 0x${hex(field.unit.raw)}`)] : '未声明'],
    ['Unit Exp.', field.unit_exponent === null ? '未声明（按 0）' : `10${superscript(field.unit_exponent)}`],
    ['Collection', field.collection_index === null ? '不在 Collection 内' : h('span', { class: 'crumbs' }, collectionPath(field.collection_index).map(name => h('span', null, name)))],
    ['来源', item ? h('button', { type: 'button', class: 'link mono', onclick: () => focusItem(item.index, true) }, `@${item.offset} ${item.name}`) : `@${field.descriptor_offset}`],
  ];
  const usages = field.usages;
  box.replaceChildren(
    h('div', { class: `detail-title ${pad ? '' : colorClass(index)}` },
      h('span', { class: `swatch${pad ? ' pad' : ''}` }), h('strong', null, `字段 #${index}`),
      h('span', { class: 'tag' }, `${kindNames[field.kind]} · ${field.report_id ? `ID ${field.report_id}` : '无 ID'}`)),
    h('p', { class: 'detail-summary' }, fieldSummary(field)),
    h('dl', { class: 'facts' }, facts.flatMap(([label, value]) => [h('dt', null, label), h('dd', null, value)])),
    pad ? null : h('div', { class: 'usages-head' }, h('span', null, 'Usage'), h('span', null, usages.length)),
    pad ? null : h('div', { class: 'usage-chips' }, usages.length
      ? [...usages.slice(0, 48).map(u => h('span', { class: 'usage-chip', title: usageCode(u) }, usageName(u))), usages.length > 48 ? h('span', { class: 'usage-chip dim' }, `另有 ${usages.length - 48} 个`) : null]
      : h('span', { class: 'dim' }, '未声明')),
    h('p', { class: 'detail-note' }, '解码值保留原始整数；Physical 与单位只作为元数据显示，不做换算。'));
}
function renderCollections() {
  const box = $('collections');
  if (!state.descriptor) { $('collection-meta').textContent = ''; return box.replaceChildren(empty('暂无 Collection。')); }
  const collections = state.descriptor.layout.collections;
  $('collection-meta').textContent = plural(collections.length, '个');
  if (!collections.length) return box.replaceChildren(empty('字段都在 Collection 之外。'));
  const depthOf = index => { let depth = 0; for (let p = collections[index].parent_index; p !== null && depth < 64; p = collections[p].parent_index) depth++; return depth; };
  box.replaceChildren(h('ol', null, collections.slice(0, COLLECTION_LIMIT).map((c, index) => h('li', null,
    h('button', { type: 'button', class: 'coll', dataset: { collection: index }, title: `#${index} · ${usageCode(c.usage)}`, onclick: () => focusCollection(index) },
      depthOf(index) ? h('span', { class: 'indent', style: `--depth:${Math.min(depthOf(index), 8)}` }) : null,
      h('span', { class: 'name' }, usageName(c.usage) ?? '未声明 Usage'),
      h('span', { class: 'type' }, collectionTypes[c.collection_type] ?? `类型 ${c.collection_type}`),
      h('span', { class: 'range' }, `@${c.descriptor_offset}–${c.end_offset}`))))),
  collections.length > COLLECTION_LIMIT ? empty(`只列出前 ${COLLECTION_LIMIT} 个；完整列表见导出的 JSON。`) : '');
}
function paintDescriptor(reveal = false) {
  if (state.descriptorError) {
    const range = descriptorEditor.errorRange(state.descriptorError);
    return descriptorEditor.setMarks(range ? [{ start: range[0], end: range[1], tone: 'error' }] : [], reveal);
  }
  if (!state.descriptor) return descriptorEditor.setMarks([]);
  if (state.focus) return descriptorEditor.setMarks([markFor(state.focus.start, state.focus.end, 'focus')], reveal);
  const index = focusedItem();
  const item = index === null ? null : state.info.items[index];
  descriptorEditor.setMarks(item ? [markFor(item.offset, item.end, 'focus')] : [], reveal);
}
function paintReport() {
  if (state.reportError) {
    const range = reportEditor.errorRange(state.reportError);
    return reportEditor.setMarks(range && state.reportError.error.code !== 'report_length' ? [{ start: range[0], end: range[1], tone: 'error' }] : []);
  }
  if (!state.decoded || state.selected === null) return reportEditor.setMarks([]);
  const field = state.descriptor.layout.fields[state.selected];
  if (field.bit_size * field.count === 0) return reportEditor.setMarks([]);
  const { first, last } = wireBytesOf(field);
  const range = reportEditor.byteRange(first, last + 1);
  reportEditor.setMarks(range ? [{ start: range[0], end: range[1], tone: 'focus' }] : []);
}

// ---------- Actions ----------
function loadFixture(fixture) {
  state.fixture = { ...fixture, pending: true };
  state.selected = null;
  descriptorEditor.value = fixture.descriptor_hex;
  scheduleDescriptor.now();
}
function exportJson() {
  const report = currentReport();
  const result = { schema_version: 1, descriptor: state.descriptor, selected_report: { kind: report.kind, report_id: report.report_id }, wire_hex: state.wireHex, decoded: state.decoded };
  const url = URL.createObjectURL(new Blob([JSON.stringify(result, null, 2) + '\n'], { type: 'application/json' }));
  h('a', { href: url, download: 'moonhid-inspection.json' }).click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

$('descriptor').addEventListener('input', () => {
  state.fixture = null;
  renderFixtures();
  descriptorEditor.setMarks([]);
  scheduleDescriptor();
});
$('report').addEventListener('input', () => {
  if (state.reportKey) state.drafts.set(state.reportKey, reportEditor.value);
  reportEditor.setMarks([]);
  scheduleReport();
});
for (const [id, run] of [['descriptor', () => scheduleDescriptor.now()], ['report', () => scheduleReport.now()]]) {
  $(id).addEventListener('keydown', event => { if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) { event.preventDefault(); run(); } });
}
$('sample-report').addEventListener('click', () => {
  const sample = sampleFor(currentReport());
  reportEditor.value = sample;
  state.drafts.set(state.reportKey, sample);
  decodeReport();
  applySelection();
});
$('export').addEventListener('click', exportJson);

try {
  core = await import('./moonhid-core.js');
  fixtures = JSON.parse(core.examples_json());
  $('fixtures').replaceChildren(...fixtures.map(fixture => h('button', {
    type: 'button', 'aria-pressed': 'false', dataset: { fixture: fixture.name }, onclick: () => loadFixture(fixture),
  }, fixtureNames[fixture.name] ?? fixture.name)));
  loadFixture(fixtures[0]);
} catch (error) {
  console.error(error);
  $('boot-error').hidden = false;
  $('descriptor').disabled = true;
  setStatus('descriptor-status', 'error', h('span', { class: 'status-text' }, '解析器加载失败，请检查构建步骤。'));
}
