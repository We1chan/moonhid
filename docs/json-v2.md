# MoonHID JSON schema v2

v2 增加超宽字段原始字节解码和区间 Usage；历史格式见 [JSON v1](json-v1.md)。

`descriptor_to_json(Bytes)` 返回 `Result[Json, Diagnostic]`，成功值是版本化描述符文档。
`layout_to_json`、`report_to_json` 和 `diagnostic_to_json` 返回其中的组件。
版本字段为整数 `schema_version: 2`；不兼容的字段或语义变更会增加版本号。
对象键顺序不作为契约，数组顺序按描述符声明和报告元素顺序保留。

## 描述符文档

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `schema_version` | integer | 当前为 2 |
| `descriptor_hex` | string | 小写、空格分隔的字节对 |
| `byte_length` | integer | 描述符长度 |
| `items` | array | `offset`, `type_code`, `tag`, `data_hex`, `is_long` |
| `layout.has_report_ids` | boolean | 是否使用 ID 前缀 |
| `layout.reports` | array | `kind`, `report_id`, `payload_bits`, `wire_bytes` |
| `layout.collections` | array | Collection 元数据，顺序即其索引 |
| `layout.fields` | array | Main 报告字段，顺序即其索引；保留 Constant |

`kind` 取 `"input"`、`"output"`、`"feature"`。没有 ID 前缀时 `report_id` 为 0。
`payload_bits` 不包含 ID，`wire_bytes` 包含 ID 及不足一个字节的尾部位。
`reports` 按每个方向/ID 在描述符中第一次出现的顺序列出。
Item 的 `type_code` 是 HID 原始值：Main=0、Global=1、Local=2、Reserved=3。
长项可通过 `parse_items` 检查，但 `descriptor_to_json` 会拒绝布局编译不支持的语义。

Collection 对象含 `descriptor_offset`、`end_offset`（对应 End Collection 的字节位置）、
`collection_type`、`usage`、`parent_index`。根集合的 `parent_index` 为 `null`。
Usage 为 `{ "page": integer, "id": integer }`；缺少 Usage 时为 `null`。
所有索引从 0 开始；数组长度、位宽等限制见 README。

Usage 区间为 `{ "page": integer, "min": integer, "max": integer }`，端点包含在内，
`usage_count` 是区间长度之和。单项 Usage 使用 min=max；区间按声明顺序保留，
最多 1024 段。解码值中的 `usage` 仍为 `{page,id}` 或 null。

字段含 `descriptor_offset`、`kind`、`report_id`、`bit_offset`、`bit_size`、`count`、
`flags`、`logical_min`、`logical_max`、`usage_spans`、`usage_count` 以及以下元数据：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `physical_min`, `physical_max` | number or null | 描述符中的声明，缺少则为 null |
| `effective_physical_min`, `effective_physical_max` | number | 缺少任一端点或两端为 0 时采用 Logical |
| `unit` | object or null | Unit 原始值和维度，缺少则为 null |
| `unit_exponent` | integer or null | -8..7，缺少则为 null，有效默认值为 0 |
| `collection_index` | integer or null | 最内层所属集合索引，集合外为 null |

Unit 对象含 `raw`、`system`、`length`、`mass`、`time`、`temperature`、`current`、
`luminous_intensity`、`reserved`。维度为有符号四位指数，`system` 和 `reserved` 为无符号四位值。
保留不认识的系统值和保留位，避免默认为某种单位。此版本不执行物理单位转换。
报告字段位偏移是 **载荷偏移**，不包含首字节 ID；从最低位开始提取。

## 解码组件

`report_to_json` 返回 `{ "kind": ..., "report_id": ..., "values": [...], "opaque_values": [...] }`。
每个值含 `field_index`、`element_index`、`bit_offset`、`value`、`usage`、`is_array`、
`in_logical_range`、`is_null`。`field_index` 引用完整 `layout.fields`，不随方向筛选而重新编号。
Constant 字段不产生解码值。未映射的数组 Usage 为 `null`，整数值仍保留。

超过 32 位的 Data Variable 元素放入 `opaque_values`，每个值含
`field_index`、`element_index`、`bit_offset`、`bit_size`、`hex`。
`hex` 为小写空格分隔字节；按 LSB 位序打包，与源载荷是否字节对齐无关，
最后一个字节的未使用高位补 0。字段偏移仍不包含 Report ID。
Constant 字段不产生整数或原始字节值；Data Array 位宽仍限制 1..32 位。

整数范围为有符号或无符号 32 位；所有 HID 数值序列化为 JSON **number**，
包括 `4294967295`，可由 JavaScript 精确表示。内部计算使用 Int64，但不使用其默认字符串 JSON 编码。
这些保证适用于编译器生成的有效布局与解码结果，序列化 API 不校验调用者手工构造的布局。

## 浏览器桥接与下载文件

浏览器 ES 模块导出三个函数：

- `inspect_descriptor(hex)` → `{ "ok": true, "schema_version": 2, "descriptor": ... }`
- `decode_wire(descriptor_hex, kind, report_hex)` → `{ "ok": true, "schema_version": 2, "wire_hex": ..., "decoded": ... }`
- `examples_json()` → 鼠标、键盘、手柄样例数组，含 `name`, `descriptor_hex`, `input_hex`, `expected_values`, `output_hex`。

所有参数及返回值都是原生 JavaScript 字符串；返回值再用 `JSON.parse` 读取。
失败格式为 `{ "ok": false, "schema_version": 2, "stage": ..., "error": { "offset": ..., "code": ..., "message": ... } }`。
`stage` 是 `descriptor_hex`、`descriptor`、`report_hex` 或 `report`。
十六进制阶段的 offset 是原始文本 UTF-16 索引，二进制阶段是零起始字节偏移。
`report_length` 的 offset 为实际收到的字节数，EOF 错误可指向输入末尾。

下载的 `moonhid-inspection.json` 包含：

```json
{
  "schema_version": 2,
  "descriptor": { "schema_version": 2, "descriptor_hex": "...", "byte_length": 0, "items": [], "layout": {} },
  "selected_report": { "kind": "input", "report_id": 0 },
  "wire_hex": null,
  "decoded": null
}
```

上例展示结构，省略了有效描述符的内部数据。成功解码后最后两个字段分别变为
规范化报告十六进制和解码组件；当前报告为空或未通过检查时为 `null`。
描述符未通过检查时导出按钮禁用。格式可保存复现问题，本版尚无 JSON 文件导入功能。
