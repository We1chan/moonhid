# 结构化描述符声明 v1

0.6.0 新增 `descriptor_from_declaration(String) -> Result[Bytes, Diagnostic]` 与
`declaration_from_descriptor(Bytes) -> Result[Json, Diagnostic]`，以及 CLI `build` / `declare`。
声明描述的是如何生成原始 HID 描述符，使用独立 schema **version 1**；
描述符展示与解码结果仍使用 [JSON schema v2](json-v2.md)，不能把 inspect JSON 当成声明输入。

## 最小例子

```json
{
  "version": 1,
  "items": [
    {"usage_page": 1}, {"usage": 5},
    {"collection": "application", "items": [
      {"usage": "0x39"}, {"logical_range": [0, 7]},
      {"report_size": 4}, {"report_count": 1},
      {"input": ["data", "variable", "null_state"]},
      {"input": ["constant"]}
    ]}
  ]
}
```

每个节点恰有一个 item 键，可另带 `size`；Collection 另带 `items` 子数组，编译时自动补零长度 End Collection。
Global 在 Collection 结束后仍然有效，只有 Push/Pop 才保存/恢复它。Local 状态仍按每个 Main item 清空。
数值允许 JSON 整数或以 `0x` 开头的十六进制字符串，支持负数和 `-0x`。浮点、非有限数及超出 32 位原始域的值拒绝。

## 支持的键

| 类别 | item 键与值 |
| --- | --- |
| Global | `usage_page`、`logical_minimum`、`logical_maximum`、`physical_minimum`、`physical_maximum`、`unit_exponent`、`unit`、`report_size`、`report_id`、`report_count`：整数；`push`、`pop`：true |
| Local | `usage`：ID 整数或 `{ "page": 0..65535, "id": 0..65535 }`；`usage_minimum`、`usage_maximum`、`string_index`、`string_minimum`、`string_maximum`、`designator_index`、`designator_minimum`、`designator_maximum`、`delimiter`：整数 |
| Main | `input`、`output`、`feature`：数字 flags 或名称数组；`collection`：名称或数字类型，且必须有 `items` 子数组 |
| 便捷范围 | `logical_range: [min, max]`、`usage_range: [min, max]`；展开为对应的 Minimum、Maximum 两个项 |

Collection 名称为 `physical`、`application`、`logical`、`report`、`named_array`、`usage_switch`、`usage_modifier`，
对应类型 0..6；其他允许的 Collection 类型可用数字声明。End Collection 由树结构生成，不接受额外的显式结束键。

Main flags 名称及相反取值：

| 位 | 清零名称 | 置位名称 |
| --- | --- | --- |
| 0 | `data` | `constant` |
| 1 | `array` | `variable` |
| 2 | `absolute` | `relative` |
| 3 | `no_wrap` | `wrap` |
| 4 | `linear` | `non_linear` |
| 5 | `preferred_state` | `no_preferred_state` |
| 6 | `no_null_state` | `null_state` |
| 7 | `non_volatile` | `volatile` |
| 8 | `bit_field` | `buffered_bytes` |

未提及的位为 0；同组相反名称同时出现会报错。Buffered Bytes 的对齐及完整字节流语义见 [兼容说明](hid-compatibility.md)。

## 默认编码与原始宽度

省略 `size` 时复用 `DescriptorBuilder` 的规则：整数采用最短的 1/2/4 字节，Minimum 为有符号，
Maximum 根据有效 Minimum 选择读法，并尽量使两种读法一致。例如非负下限下 255 生成 `26 ff 00`。
默认 `unit_exponent` 取 -8..7 并用四位编码，扩展 Usage 始终为四字节，Push/Pop 为零字节载荷。

显式 `size` 必须是 **0、1、2、4**，表示直接重放 item 的原始数据宽度：

- 非负值直接表示该宽度的无符号位；负值用该宽度的二进制补码，必须可表示。零长度项只允许值为 0。
- 例如 `{"logical_minimum":129,"size":1}` 保存原字节 `15 81`；编译器仍将其解释为 -127。
- `{"unit_exponent":12,"size":1}` 为 `55 0c`，`{"unit_exponent":252,"size":1}` 为 `55 fc`，两者都解读为 -4，原始字节不同。
- 扩展 Usage 对象只允许 size 4；普通 Usage 使用显式四字节值时保留携带 page 的原始编码。
- 范围便捷写法上的 size 应用于两个端点；需要分别指定宽度时使用两个独立 item。
- Report ID、Collection、Push/Pop 等项的协议宽度限制仍由核心验证，不能用 size 绕过。

导出函数为每个原始短项写入无符号 payload 数值和显式 size，并保留 Collection 树。
因此既能保留非最短编码、零长度项、符号扩展、String/Designator 和 Delimiter，也不会重新优化字节。
保证的是描述符字节往返，不保存原 JSON 的排版、键顺序或便捷写法。
JSON 解析沿用 MoonBit 核心的对象与字符串规则。

## CLI 与样例

```sh
moon run src/cmd/moonhid --target js -- build examples/declarations/keyboard.json
moon run src/cmd/moonhid --target js -- declare examples/codec/keyboard.hex
```

`build` 输出十六进制，`declare` 输出声明 JSON；二者均可使用 `--target native`。
将 declare 的输出保存为 UTF-8 JSON 后再 build，得到完全相同的描述符字节。
声明应保存为无 BOM 的 UTF-8；PowerShell 7 可用 `Set-Content -Encoding utf8`。
旧版 PowerShell 可用 `[IO.File]::WriteAllText(path, text, [Text.UTF8Encoding]::new($false))`，避免默认重定向写成 UTF-16。

五个模板声明位于 [mouse](../examples/declarations/mouse.json)、[keyboard](../examples/declarations/keyboard.json)、
[gamepad](../examples/declarations/gamepad.json)、[consumer](../examples/declarations/consumer.json)、[vendor](../examples/declarations/vendor.json)，
其 build 输出与 `generate <name>` 逐字节相同。
[复合设备声明](../examples/declarations/composite.json) 包含嵌套集合、Push/Pop、多个 ID 和 Feature，
预期字节单独保存在 [composite.hex](../examples/declarations/composite.hex)。

## 诊断与资源限制

| 码 | 条件 | offset / 路径 |
| --- | --- | --- |
| `declaration_json` | JSON 语法、字符串或解析器嵌套限制错误 | offset 0，message 以 `$` 开头 |
| `declaration_key` | 未知键、多个 item 键、缺少 item 键，或把 children 放到非 Collection | 从 0 开始的节点先序编号，message 含对应 JSON 路径 |
| `declaration_value` | 类型、数值、size、flags、范围或最终编译语义错误 | 节点先序编号；最终编译错误映射回来源节点，message 还保留核心诊断码 |
| `declaration_limit` | 文本、声明节点、描述符字节、Collection 深度或 Global 栈超过限额 | 节点编号；文档级文本限额 offset 为 0 |

先序编号包含 Collection 节点；一个范围节点生成两个 item，但只占一个声明节点编号。
自动 End Collection 的来源为对应 Collection 节点。便捷写法与嵌套路径可定位到 `$.items[3].items[0].input` 这样的具体位置。
根文档错误使用 offset 0。最终编译失败归到 `declaration_value` 并携带原错误名，不会静默忽略不支持的语义。

声明文本最多 8388608 个 UTF-16 code unit，最多 65536 个节点；Collection 与 Global 栈最多 64 层，
仍受核心描述符 65536 字节、报告总位数与字段数量限制。
导出先通过 `compile_descriptor`，不能导出长项、保留项或其他核心拒绝的布局；此时返回原二进制诊断和字节偏移。
原始 tokenizer/`serialize_items` 的无语义保留能力与这套可编译声明范围不同。

## 验证与独立对照边界

- `src/declaration_test.mbt` 在四后端验证语义默认值、精确宽度、七份真实描述符、元数据、节点路径和资源边界。
- `scripts/test-cli.mjs` 在 JS/native 验证五个模板、复合设备、七份真实描述符和全部九份 codec 描述符的逐字节往返及错误退出码。
- `scripts/compare-hid-tools.py` 将声明实际编译的复合描述符与 hid-tools 0.12 对照，独立核对报告、字段偏移、范围与 Usage。

对照时发现 hid-tools 0.12 的 `_parse_item` 把 Report ID 保存到 Local 对象，而 Push/Pop 只恢复 Global 对象，
因此不能用它证明 Report ID 的栈恢复。复合声明在 Pop 后显式重新声明 ID 1，保留其余 Global 恢复的对照。
MoonHID 另以固定预期测试不重复声明 ID 时的恢复。
Report ID 列在 [HID 1.11 §6.2.2.7 Global items](https://www.usb.org/sites/default/files/hid1_11.pdf) 中，Push/Pop 操作全局状态；
这部分规则不会因独立工具的实现差异而修改。

复合声明为合成数据，七份真实描述符仍单独列为结构证据，均不代表新增设备通信实测。

2026-10-22 本机验证：四后端各 119/119，native 与 JS CLI 的模板、复合与 16 个真实/codec 往返通过；
hid-tools 0.12 的七份真实布局和复合声明对照均无差异。一键完整验收为 PASS 22 / FAIL 0 / SKIP 0，
含既有浏览器、离线包、固件和编码对照。执行环境与阶段证据保持分级记录。
