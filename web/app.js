const $ = id => document.getElementById(id);
const kinds = { input: 'Input · 输入', output: 'Output · 输出', feature: 'Feature · 特性' };
const fixtureNames = { mouse: '鼠标', keyboard: '键盘', gamepad: '手柄' };
const collectionTypes = ['Physical', 'Application', 'Logical', 'Report', 'Named Array', 'Usage Switch', 'Usage Modifier'];
const unitSystems = ['无单位', 'SI Linear', 'SI Rotation', 'English Linear', 'English Rotation'];
const genericUsages = { 1: 'Pointer', 2: 'Mouse', 4: 'Joystick', 5: 'Game Pad', 6: 'Keyboard', 0x30: 'X', 0x31: 'Y', 0x32: 'Z', 0x33: 'Rx', 0x34: 'Ry', 0x35: 'Rz', 0x38: 'Wheel', 0x39: 'Hat Switch' };
const modifierNames = ['Left Ctrl', 'Left Shift', 'Left Alt', 'Left GUI', 'Right Ctrl', 'Right Shift', 'Right Alt', 'Right GUI'];
const mainTags = { 8: 'Input', 9: 'Output', 10: 'Collection', 11: 'Feature', 12: 'End Collection' };
const globalTags = ['Usage Page', 'Logical Minimum', 'Logical Maximum', 'Physical Minimum', 'Physical Maximum', 'Unit Exponent', 'Unit', 'Report Size', 'Report ID', 'Report Count', 'Push', 'Pop'];
const localTags = { 0: 'Usage', 1: 'Usage Minimum', 2: 'Usage Maximum' };
const MAX_TEXT = 393216;
const PAGE_SIZE = 200;
let core, fixtures = [], activeFixture = null, descriptor = null, decoded = null, wireHex = null, selectedField = null;
let descriptorError = null, reportError = null;

function el(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined && text !== null) node.textContent = text;
  if (className) node.className = className;
  return node;
}
function hex(n, width = 2) { return n.toString(16).padStart(width, '0'); }
function status(id, message, tone = '') {
  $(id).textContent = message;
  $(id).className = `status ${tone}`;
}
function usageName(usage) {
  if (!usage) return '未声明 Usage';
  if (usage.page === 1) return genericUsages[usage.id] ?? 'Generic Desktop';
  if (usage.page === 9) return `Button ${usage.id}`;
  if (usage.page === 8) return ['LED 0', 'Num Lock', 'Caps Lock', 'Scroll Lock', 'Compose', 'Kana'][usage.id] ?? `LED ${usage.id}`;
  if (usage.page === 7) {
    if (usage.id === 0) return 'No event';
    if (usage.id >= 4 && usage.id <= 29) return `Key ${String.fromCharCode(65 + usage.id - 4)}`;
    if (usage.id >= 0xe0 && usage.id <= 0xe7) return modifierNames[usage.id - 0xe0];
    return `Keyboard ${usage.id}`;
  }
  return 'Usage';
}
function usageCode(usage) { return usage ? `${hex(usage.page, 4)}:${hex(usage.id, 4)}` : '—'; }
function usageCell(usage) {
  const cell = el('td');
  cell.append(el('span', usageName(usage), 'usage-name'), el('span', usageCode(usage), 'usage-code'));
  return cell;
}
function selectedReport() {
  return descriptor?.layout.reports.find(r => r.kind === $('kind').value && r.report_id === Number($('report-id').value));
}
function currentFields() {
  if (!descriptor) return [];
  return descriptor.layout.fields.map((field, index) => ({ field, index })).filter(({ field }) => field.kind === $('kind').value && field.report_id === Number($('report-id').value));
}
function fieldsLabel(field) {
  if (field.flags & 1) return 'Constant · 填充';
  if (!(field.flags & 2)) return 'Array · 选择值';
  return field.usages.slice(0, 3).map(usageName).join(' / ') + (field.usages.length > 3 ? ' …' : '') || 'Variable';
}
function clearDecoded(message = '报告已修改，请重新解码。') {
  decoded = null;
  wireHex = null;
  reportError = null;
  $('report-error-position').hidden = true;
  $('decoded-count').textContent = '等待报告';
  $('wire-size').textContent = 'HEX';
  $('decoded').replaceChildren(el('p', message, 'empty'));
  status('report-status', message);
}
function resetLayout(message) {
  descriptor = null;
  selectedField = null;
  descriptorError = null;
  for (const id of ['kind', 'report-id', 'decode', 'export']) $(id).disabled = true;
  $('kind').replaceChildren();
  $('report-id').replaceChildren();
  for (const id of ['summary', 'fields', 'field-detail', 'collections', 'items']) $(id).replaceChildren(el('p', '解析后显示。', 'empty'));
  $('bit-layout').replaceChildren();
  $('descriptor-size').textContent = 'HEX';
  $('field-count').textContent = '0 fields';
  $('collection-count').textContent = '0 collections';
  $('item-count').textContent = '0 items';
  $('layout-label').textContent = '载荷位布局';
  $('descriptor-error-position').hidden = true;
  $('sample-report').hidden = true;
  clearDecoded('先解析描述符。');
  status('descriptor-status', message);
}
function diagnosticMessage(result) {
  const labels = { descriptor_hex: '描述符文本', descriptor: '描述符', report_hex: '报告文本', report: '报告' };
  const unit = result.stage.endsWith('_hex') ? '字符' : '字节';
  return `${labels[result.stage] ?? result.stage} ${unit}偏移 ${result.error.offset} · ${result.error.code}：${result.error.message}`;
}
function inputGuard(text, stage) {
  return text.length > MAX_TEXT ? { ok: false, stage, error: { offset: MAX_TEXT, code: 'text_limit', message: '十六进制文本超过 393216 字符，请减少输入。' } } : null;
}
function inspect(autoDecode = true) {
  const result = inputGuard($('descriptor').value, 'descriptor_hex') ?? JSON.parse(core.inspect_descriptor($('descriptor').value));
  if (!result.ok) {
    resetLayout('描述符未通过检查。');
    descriptorError = result;
    $('descriptor-error-position').hidden = false;
    status('descriptor-status', diagnosticMessage(result), 'error');
    return;
  }
  descriptor = result.descriptor;
  descriptorError = null;
  $('descriptor-error-position').hidden = true;
  $('descriptor-size').textContent = `${descriptor.byte_length} bytes`;
  for (const id of ['kind', 'report-id', 'decode', 'export']) $(id).disabled = false;
  $('kind').replaceChildren(...Object.entries(kinds).filter(([kind]) => descriptor.layout.reports.some(r => r.kind === kind)).map(([kind, label]) => {
    const option = el('option', label); option.value = kind; return option;
  }));
  clearDecoded('布局已就绪，可解码报告。');
  refreshReportIds();
  renderSummary();
  renderCollections();
  renderItems();
  status('descriptor-status', `解析完成 · ${descriptor.items.length} items / ${descriptor.layout.fields.length} fields`, 'success');
  if (autoDecode && $('report').value.trim()) decode();
}
function refreshReportIds() {
  const previous = Number($('report-id').value);
  const reports = descriptor.layout.reports.filter(r => r.kind === $('kind').value);
  $('report-id').replaceChildren(...reports.map(report => {
    const option = el('option', report.report_id === 0 ? '无前缀 · ID 0' : `ID ${report.report_id}`);
    option.value = String(report.report_id); return option;
  }));
  if (reports.some(r => r.report_id === previous)) $('report-id').value = String(previous);
  updateSelection();
}
function updateSelection() {
  clearDecoded('报告方向或 ID 已选择，请解码对应的原始报告。');
  const report = selectedReport();
  $('layout-label').textContent = `${kinds[report.kind]} · ID ${report.report_id} · ${report.payload_bits} 载荷位 / ${report.wire_bytes} 字节`;
  const sample = sampleForDirection();
  $('sample-report').hidden = !sample;
  renderFields();
  const first = currentFields().find(({ field }) => !(field.flags & 1)) ?? currentFields()[0];
  selectField(first.index);
}
function sampleForDirection() {
  if (!activeFixture || descriptor?.descriptor_hex !== activeFixture.descriptor_hex) return null;
  if ($('kind').value === 'input') return activeFixture.input_hex;
  if ($('kind').value === 'output') return activeFixture.output_hex;
  return null;
}
function decode() {
  if (!descriptor) return;
  clearDecoded('正在解码…');
  const result = inputGuard($('report').value, 'report_hex') ?? JSON.parse(core.decode_wire(descriptor.descriptor_hex, $('kind').value, $('report').value));
  if (!result.ok) {
    reportError = result;
    $('report-error-position').hidden = false;
    status('report-status', diagnosticMessage(result), 'error');
    $('decoded-count').textContent = '报告错误';
    $('decoded').replaceChildren(el('p', '报告未通过检查。请修正输入后重新解码。', 'empty'));
    return;
  }
  if (result.decoded.report_id !== Number($('report-id').value)) {
    reportError = { stage: 'report', error: { offset: 0, code: 'report_id_selection', message: `报告首字节为 ID ${result.decoded.report_id}，当前选择 ID ${$('report-id').value}。请选择对应 ID。` } };
    status('report-status', diagnosticMessage(reportError), 'error');
    $('report-error-position').hidden = false;
    $('decoded-count').textContent = 'ID 不匹配';
    $('decoded').replaceChildren(el('p', '报告 ID 与当前布局不一致。', 'empty'));
    return;
  }
  decoded = result.decoded;
  wireHex = result.wire_hex;
  const invalid = decoded.values.filter(v => !v.in_logical_range && !v.is_null).length;
  const nulls = decoded.values.filter(v => v.is_null).length;
  $('wire-size').textContent = `${selectedReport().wire_bytes} bytes`;
  $('decoded-count').textContent = `${decoded.values.length} values`;
  status('report-status', `解码完成 · ${decoded.values.length} 个值${invalid ? ` / ${invalid} 个越界值` : ''}${nulls ? ` / ${nulls} 个 Null State` : ''}`, invalid ? 'warning' : 'success');
  renderDecoded();
}
function renderSummary() {
  const statistics = [[descriptor.byte_length, '描述符字节'], [descriptor.layout.fields.length, 'Main 字段'], [descriptor.layout.collections.length, 'Collections'], [descriptor.layout.reports.length, '报告布局']];
  $('summary').replaceChildren(...statistics.map(([value, label]) => {
    const node = el('div', null, 'stat'); node.append(el('strong', value), el('span', label)); return node;
  }));
}
function renderBitLayout() {
  const segments = [];
  if (descriptor.layout.has_report_ids) {
    const prefix = el('div', `ID ${$('report-id').value}`, 'bit-segment prefix');
    prefix.append(el('span', '前缀 · 8 bit')); segments.push(prefix);
  }
  const fields = currentFields();
  for (const { field, index } of fields.slice(0, 128)) {
    const node = el('button', fieldsLabel(field), `bit-segment${field.flags & 1 ? ' padding' : ''}${index === selectedField ? ' selected' : ''}`);
    node.dataset.fieldIndex = index;
    node.style.flexGrow = Math.min(12, field.bit_size * field.count);
    node.title = `字段 #${index} · ${field.bit_offset}..${field.bit_offset + field.bit_size * field.count - 1} bit`;
    node.append(el('span', `${field.bit_offset}..${field.bit_offset + field.bit_size * field.count - 1} · ${field.bit_size} × ${field.count}`));
    node.addEventListener('click', () => selectField(index)); segments.push(node);
  }
  if (fields.length > 128) segments.push(el('span', `另有 ${fields.length - 128} 个字段，完整数据见下方字段表与 JSON。`, 'bit-overflow'));
  $('bit-layout').replaceChildren(...segments);
}
// Long valid descriptors stay usable: tables render one page, never every value.
function tableView(containerId, headers, rows, renderRow) {
  let page = 0;
  function render() {
    const table = el('table');
    const header = el('tr'); header.append(...headers.map(h => el('th', h)));
    const thead = el('thead'); thead.append(header);
    const tbody = el('tbody'); tbody.append(...rows.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE).map(renderRow));
    table.append(thead, tbody);
    const children = [table];
    if (rows.length > PAGE_SIZE) {
      const paging = el('div', null, 'pagination');
      const previous = el('button', '上一页'); previous.disabled = page === 0;
      const next = el('button', '下一页'); next.disabled = (page + 1) * PAGE_SIZE >= rows.length;
      previous.addEventListener('click', () => { page--; render(); });
      next.addEventListener('click', () => { page++; render(); });
      paging.append(previous, el('span', `${page * PAGE_SIZE + 1}–${Math.min(rows.length, (page + 1) * PAGE_SIZE)} / ${rows.length}`), next); children.push(paging);
    }
    $(containerId).replaceChildren(...children);
    $(containerId).scrollTop = 0;
  }
  render();
}
function fieldButton(index) {
  const button = el('button', `#${index}`, 'row-button');
  button.addEventListener('click', () => selectField(index)); return button;
}
function sourceButton(offset) {
  const button = el('button', `@${offset}`, 'row-button source-button');
  button.title = `描述符字节偏移 ${offset}`;
  button.addEventListener('click', () => locateItem(offset)); return button;
}
function renderFields() {
  const fields = currentFields();
  $('field-count').textContent = `${fields.length} fields`;
  tableView('fields', ['字段', '起始位', '位宽 × 数量', '类型 / Usage', '来源'], fields, ({ field, index }) => {
    const row = el('tr'); row.dataset.fieldIndex = index;
    const link = el('td'); link.append(fieldButton(index));
    const source = el('td'); source.append(sourceButton(field.descriptor_offset));
    row.append(link, el('td', field.bit_offset, 'mono'), el('td', `${field.bit_size} × ${field.count}`, 'mono'), el('td', fieldsLabel(field)), source);
    return row;
  });
}
function renderDecoded() {
  tableView('decoded', ['字段 / 元素', 'Usage', '载荷位', '整数值', '状态'], decoded.values, value => {
    const field = descriptor.layout.fields[value.field_index];
    const row = el('tr'); row.dataset.fieldIndex = value.field_index;
    const link = el('td'); link.append(fieldButton(value.field_index), el('span', ` [${value.element_index}]`, 'mono muted'));
    const state = el('td');
    state.append(el('span', value.is_null ? 'Null State' : !value.in_logical_range ? '越界' : value.is_array ? 'Array' : field.flags & 4 ? 'Relative' : 'Variable', `tag${value.is_null ? ' warn' : !value.in_logical_range ? ' bad' : ''}`));
    row.append(link, usageCell(value.usage), el('td', `${value.bit_offset}..${value.bit_offset + field.bit_size - 1}`, 'mono muted'), el('td', value.value, 'value-cell'), state);
    return row;
  });
  highlightField();
}
function collectionPath(index) {
  const path = [];
  for (let depth = 0; index !== null && depth < 64; depth++) {
    const c = descriptor.layout.collections[index];
    path.unshift(`${usageName(c.usage)} (#${index})`); index = c.parent_index;
  }
  return path.join(' / ') || '集合外';
}
function selectField(index, rerenderBits = true) {
  selectedField = index;
  const field = descriptor.layout.fields[index];
  const flags = [field.flags & 1 ? 'Constant' : 'Data', field.flags & 2 ? 'Variable' : 'Array', field.flags & 4 ? 'Relative' : 'Absolute'];
  for (const [bit, name] of [[8, 'Wrap'], [16, 'Nonlinear'], [32, 'No Preferred'], [64, 'Null State'], [128, 'Volatile']]) if (field.flags & bit) flags.push(name);
  const dimensions = field.unit ? ['length', 'mass', 'time', 'temperature', 'current', 'luminous_intensity'].map((key, n) => field.unit[key] ? `${['L', 'M', 'T', 'Θ', 'I', 'J'][n]}^${field.unit[key]}` : null).filter(Boolean).join(' · ') || '无量纲' : '未声明';
  const detail = el('dl', null, 'detail-grid');
  const rows = [
    ['报告', `${kinds[field.kind]} / ID ${field.report_id}`],
    ['Flags', `0x${hex(field.flags)} · ${flags.join(' / ')}`],
    ['Logical', `${field.logical_min} … ${field.logical_max}`],
    ['Physical 声明', `${field.physical_min ?? '未声明'} … ${field.physical_max ?? '未声明'}`],
    ['Physical 有效', `${field.effective_physical_min} … ${field.effective_physical_max}`],
    ['Unit', field.unit ? `${unitSystems[field.unit.system] ?? `保留系统 ${field.unit.system}`} · 0x${hex(field.unit.raw)}` : '未声明'],
    ['维度 / 指数', `${dimensions} / ${field.unit_exponent === null ? '未声明（默认 0）' : `10^${field.unit_exponent}`}`],
    ['所属集合', collectionPath(field.collection_index)],
    ['Usage', field.usages.slice(0, 12).map(u => `${usageName(u)} (${usageCode(u)})`).join(', ') + (field.usages.length > 12 ? ` … 共 ${field.usages.length} 项，完整列表见 JSON` : '') || '未声明'],
  ];
  for (const [label, value] of rows) detail.append(el('dt', label), el('dd', value));
  const heading = el('p', `字段 #${index} · ${field.bit_size} bit × ${field.count}`, 'detail-heading');
  heading.append(document.createTextNode(' '), sourceButton(field.descriptor_offset));
  $('field-detail').replaceChildren(heading, detail, el('p', 'Physical 缺少端点或两端均为 0 时，使用 Logical 范围。这里保留单位元数据，解码值仍为原始整数。', 'detail-note'));
  if (rerenderBits) renderBitLayout();
  highlightField();
}
function highlightField() {
  document.querySelectorAll('tr[data-field-index]').forEach(row => row.classList.toggle('is-selected', Number(row.dataset.fieldIndex) === selectedField));
}
function renderCollections() {
  const collections = descriptor.layout.collections;
  $('collection-count').textContent = `${collections.length} collections`;
  if (!collections.length) { $('collections').replaceChildren(el('p', '字段声明在集合外。', 'empty')); return; }
  const rows = collections.map((collection, index) => ({ collection, index }));
  tableView('collections', ['Collection', '类型', '范围'], rows, ({ collection: c, index }) => {
    let depth = 0, parent = c.parent_index;
    while (parent !== null && depth < 64) { depth++; parent = collections[parent].parent_index; }
    const row = el('tr');
    const name = usageCell(c.usage); name.style.paddingLeft = `${Math.min(depth, 6) * 12}px`;
    name.title = collectionPath(index); name.prepend(el('span', `${depth ? '↳ ' : ''}#${index} `, 'mono muted'));
    row.append(name, el('td', collectionTypes[c.collection_type] ?? `类型 ${c.collection_type}`), el('td', `@${c.descriptor_offset}…${c.end_offset}`, 'mono muted')); return row;
  });
}
function renderItems(focusOffset = null) {
  $('item-count').textContent = `${descriptor.items.length} items`;
  const items = focusOffset === null ? descriptor.items : descriptor.items.filter(item => item.offset === focusOffset);
  tableView('items', ['偏移', '类型', 'Item', 'Payload'], items, item => {
    const row = el('tr'); row.dataset.itemOffset = item.offset;
    if (item.offset === focusOffset) row.className = 'highlight';
    const names = [mainTags, globalTags, localTags];
    row.append(el('td', `@${item.offset}`, 'mono'), el('td', ['Main', 'Global', 'Local', 'Reserved'][item.type_code]), el('td', names[item.type_code]?.[item.tag] ?? `Tag ${item.tag}`), el('td', item.data_hex || '—', 'mono')); return row;
  });
  if (focusOffset !== null) {
    const reset = el('button', '显示全部 Items', 'text-button'); reset.addEventListener('click', () => renderItems()); $('items').append(reset);
  }
}
function textByteOffset(text, offset) {
  let byte = 0, digits = 0;
  for (let i = 0; i < text.length; i++) {
    if (/\s/.test(text[i])) continue;
    if (digits % 2 === 0) { if (byte === offset) return i; byte++; }
    digits++;
  }
  return text.length;
}
function locateInput(id, result) {
  const input = $(id);
  const start = result.stage.endsWith('_hex') ? result.error.offset : textByteOffset(input.value, result.error.offset);
  input.focus(); input.setSelectionRange(start, Math.min(input.value.length, start + (result.stage.endsWith('_hex') ? 1 : 2)));
}
function locateItem(offset) {
  $('items-panel').open = true;
  renderItems(offset);
  $('items-panel').scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  const start = textByteOffset($('descriptor').value, offset);
  $('descriptor').setSelectionRange(start, Math.min($('descriptor').value.length, start + 2));
}
function loadFixture(fixture) {
  activeFixture = fixture;
  $('descriptor').value = fixture.descriptor_hex;
  $('report').value = fixture.input_hex;
  document.querySelectorAll('#fixture-buttons button').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.fixture === fixture.name)));
  inspect();
}
function exportJson() {
  const result = { schema_version: 1, descriptor, selected_report: { kind: $('kind').value, report_id: Number($('report-id').value) }, wire_hex: wireHex, decoded };
  const url = URL.createObjectURL(new Blob([JSON.stringify(result, null, 2) + '\n'], { type: 'application/json' }));
  const link = el('a'); link.href = url; link.download = 'moonhid-inspection.json'; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

$('descriptor').addEventListener('input', () => {
  activeFixture = null;
  document.querySelectorAll('#fixture-buttons button').forEach(b => b.setAttribute('aria-pressed', 'false'));
  resetLayout('描述符已修改，请重新解析。');
});
$('report').addEventListener('input', () => clearDecoded(descriptor ? undefined : '先解析描述符。'));
$('inspect').addEventListener('click', () => inspect());
$('decode').addEventListener('click', decode);
$('kind').addEventListener('change', refreshReportIds);
$('report-id').addEventListener('change', updateSelection);
$('sample-report').addEventListener('click', () => { $('report').value = sampleForDirection(); decode(); });
$('export').addEventListener('click', exportJson);
$('descriptor-error-position').addEventListener('click', () => locateInput('descriptor', descriptorError));
$('report-error-position').addEventListener('click', () => locateInput('report', reportError));

try {
  core = await import('./moonhid-core.js');
  fixtures = JSON.parse(core.examples_json());
  $('fixture-buttons').replaceChildren(...fixtures.map(fixture => {
    const button = el('button', fixtureNames[fixture.name]); button.dataset.fixture = fixture.name;
    button.setAttribute('aria-pressed', 'false'); button.addEventListener('click', () => loadFixture(fixture)); return button;
  }));
  $('inspect').disabled = false;
  loadFixture(fixtures[0]);
} catch (error) {
  console.error(error);
  $('boot-error').hidden = false;
  resetLayout('解析器加载失败，请检查构建步骤。');
}
