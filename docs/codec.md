# 报告编解码、字段读写与描述符生成

以下接口来自仓库 0.4.0，尚未发布到 mooncakes.io。核心不依赖操作系统 HID API，
可在 wasm、wasm-gc、JS、native 使用。JSON schema 保持 v2。

## 描述符生成

`DescriptorBuilder::new()` 创建可链式调用的对象。`usage_page` / `usage` / `usage_range`
声明数字 Usage，`extended_usage(Usage)` 强制生成携带 page 的四字节 Usage。
`logical_range`、`report_size`、`report_count` 和 `input` / `output` / `feature` 定义字段。
Main flags 是 HID 位标志：`1` 为 Constant，`2` 为 Data Variable Absolute，
`6` 为 Data Variable Relative，`0` 为 Data Array Absolute，`0x42` 带 Null State。

`collection` / `end_collection` 定义集合；`report_id` 定义 1..255 的 ID；
`physical_range`、`unit`、`unit_exponent` 保存元数据，`push` / `pop` 保存与恢复全局状态。
`short_item(type_code, tag, value, signed=...)` 可生成其他支持的短项，例如 String/Designator 和 Delimiter。
`type_code` 为 0 Main、1 Global、2 Local；整数采用最小的 1、2、4 字节编码。
Minimum 按有符号编码，Maximum 的符号取决于 Minimum，完整 uint32 不会截断。

首个参数错误保留至 `build()`，后续调用不再追加字节。`build()` 返回 `Result[Bytes, Diagnostic]`，
并复用 `compile_descriptor` 校验集合、栈、范围、ID 模式和资源上限。
调用方显式声明填充、ID、集合结束与位宽，当前不自动推断或优化。
对象可重复 `build()`，复制其引用会共享状态；独立描述符分别调用 `new()`。

| `We1chan/moonhid/examples` 函数 / CLI 模板 | 描述符内容 | 编码预期 |
| --- | --- | --- |
| `mouse_descriptor()` / `mouse` | 三按钮、三相对轴、填充 | `05 ff 02 fe` |
| `keyboard_descriptor()` / `keyboard` | 修饰键、六元素按键数组、五 LED Output | Input `02 00 04 06 00 00 00 00`；Output `03` |
| `gamepad_descriptor()` / `gamepad` | ID 7、十二按钮、两个 signed16 轴 | `07 01 08 00 80 ff 7f` |

模板生成结果与独立保存的描述符逐字节比较。README 的可执行示例演示生成 LED 描述符、
编码 Output、按 Usage 查询并修改 Caps Lock。

`serialize_items(parse_items(bytes))` 保留短项原始宽度、零长度项、长项和保留项的数据。
序列化不解释语义，也不保证结果可编译。短项允许 0/1/2/4 字节，长项最多 255 字节，
总描述符最多 65536 字节；短项前缀 `0xfe` 与长项标记冲突而拒绝。
`Item.offset` 不写入输出；序列化错误的 offset 是 item 索引。

## 报告编码

```text
encode_report(layout, kind, report_id, values, allow_out_of_range=false)
  -> Result[Bytes, Diagnostic]
```

`values` 为 `Array[ReportValue]`，按所选方向/ID 的 `layout.fields` 顺序，再按每字段的元素顺序排列。
省略 Constant 字段；必须提供全部 Data 元素。数量、类型、位宽和逻辑范围错误分别为
`value_count`、`value_type`、`value_range`、`logical_range`。

- `Integer(Int64)` 对应 1..32 位字段，`logical_min < 0` 决定有符号编码。
  支持 signed32 与完整 uint32，跨字节按 LSB 位序写入。
- `Raw(Bytes)` 对应超过 32 位的 Variable 字段；每元素长 `ceil(bit_size / 8)`，
  末字节未用高位须为零，不应用整数逻辑范围或单位换算。
- 默认检查 Logical 范围。Null State 允许可表示的范围外整数，解码时标记 `is_null`。
  显式 `allow_out_of_range=true` 可重放其他异常原值，但仍检查位宽与类型，不截断。
- 自动添加所需 ID；新报告的 Constant 与未用尾位为零。每报告仍遵守 65536 位上限。

Array 值为逻辑选择器。`array_selector(field, Usage)` 返回 `logical_min + Usage序列索引`，
支持多个区间和非零 Minimum；找不到 Usage 为 `unknown_usage`，超范围为 `logical_range`。
它不补齐按键数组，也不把所有数组的 0 都解释成“无按键”。

## 字段读写

```text
read_field(layout, kind, wire, field_index, element_index)
  -> Result[ReportValue, Diagnostic]
write_field(layout, kind, wire, field_index, element_index, value,
            allow_out_of_range=false)
  -> Result[Bytes, Diagnostic]
find_fields(layout, kind, report_id, usage)
  -> Result[Array[FieldRef], Diagnostic]
```

字段索引属于整个 Layout，元素索引为 0..count-1。wire 包含所需 ID 且长度精确匹配；
字段必须属于所选报告，Constant 不作为数据读写。读取保留异常原值；写入采用编码的范围规则，
返回副本，保留 ID、其他元素、Constant 与未用尾位，原始 Bytes 不变。

`find_fields` 返回匹配 Data Variable Usage 的全部引用，包括重复末项 Usage；
Array 没有固定的 Usage 元素位置，应使用 `array_selector` 或查看解码结果。
超宽字段 read/write 仍用 `Raw`。

低层 `insert_bits` / `insert_bytes` 对应 `extract_bits` / `extract_bytes`，
按绝对位偏移在副本中写入，不解释 ID、Usage 或 Logical 范围。整数需显式 `signed=true`。
诊断 offset 为起始字节，非法范围与超大偏移都返回错误。

## 文件 CLI 与样例

从仓库根目录运行，native 与 Node.js 参数一致：

```sh
moon run src/cmd/moonhid --target native -- generate mouse
moon run src/cmd/moonhid --target native -- encode --kind input --id 0 examples/codec/mouse.hex examples/codec/mouse-values.json
moon run src/cmd/moonhid --target js -- encode --kind input --id 7 examples/codec/gamepad.hex examples/codec/gamepad-values.json
moon run src/cmd/moonhid --target native -- encode --kind output --id 0 examples/codec/keyboard.hex examples/codec/keyboard-led-values.json
moon run src/cmd/moonhid --target js -- encode --kind feature --id 7 examples/codec/vendor-feature.hex examples/codec/vendor-feature-values.json
```

输出依次为鼠标描述符、`05 ff 02 fe`、`07 01 08 00 80 ff 7f`、`03`、`07 f8 ff ff ff 0f`。
JSON 顶层须为数组，普通字段为整数，超宽字段为仅有 `hex` 字符串键的对象，
例如 `[{"hex":"ff ff ff ff 01"}]` 表示一个 33 位原始元素。
顺序、数量与 Null 规则同核心；CLI 采用默认严格范围，不开放异常重放开关。

成功时 stdout 为一行 hex、退出 0；输入/文件/编码错误退出 1；参数错误退出 2，错误写入 stderr。
JSON 格式错误为 `values_json`：语法/顶层错误的 offset 为 0，元素格式/数值错误为数组索引；
Raw hex 错误偏移相对于该字符串；字段错误偏移为描述符字节位置。
现有 inspect/decode JSON 与 lint 退出码 3 保持原约定。

MoonHID 无 ID 的 wire 不含额外 0；HIDAPI/node-hid 写接口要求首字节 ID（无 ID 时为 0），
由适配层添加。WebHID 的 ID 与 payload 分开传参。CLI 编码生成离线数据。
依据：[HIDAPI](https://github.com/libusb/hidapi/blob/master/hidapi/hidapi.h)、
[node-hid](https://github.com/node-hid/node-hid#writing-to-a-device)、[WebHID 规范](https://hid.spec.whatwg.org/)。

## 验证

生成器、编码器与模板测试检查独立预期字节、三方向、多 ID、跨字节、signed/unsigned32、
Array、Null、超宽值、最大报告与错误路径。现有模糊语料加入 item 无损往返和
`decode(encode(decoded_values)) == decoded_report`，显式允许异常原值；Constant 的原始位无需往返。

```sh
moon check --target all --deny-warn
moon test --target wasm
moon test --target wasm-gc
moon test --target js
moon test --target native
node scripts/test-cli.mjs
```

新生成/编码入口目前为核心、示例和 CLI；浏览器桥接与原有回归继续执行。
本次结果与环境见 [0.4.0 验收记录](codec-validation.md)。
`python scripts/compare-codec-hid-tools.py` 使用 CI 固定的 hid-tools 0.12，独立解析生成的描述符、
填入同一组字段值并比较报告字节，再独立读取 MoonHID 编码结果。覆盖鼠标、键盘、手柄 Input 和 LED Output。
