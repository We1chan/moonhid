# 报告编解码、字段读写与描述符生成

基础接口从 0.4.0 提供，安装方式见 [0.5.0 发布说明](release-0.5.0.md)。核心不依赖操作系统 HID API，
可在 wasm、wasm-gc、JS、native 使用。JSON schema 保持 v2。
Buffered Bytes 从 0.5.0 提供；0.4.0 会拒绝此标志。
标准兼容目标、三方向案例与资源边界见 [HID 1.11 兼容说明](hid-compatibility.md)。
`DecodedReport` 新增公开字段 `buffered_values`；手工构造该结构体的调用方需补上此数组（无缓冲区时为 `[]`）。
既有函数签名和整数、超宽值的返回语义不变。

接口分三层，可以混用：

| 层 | 适合场景 | 接口 | 对应的成熟库接口 |
| --- | --- | --- | --- |
| Usage 级 | 按键、LED、摇杆、媒体键等按语义读写 | `new_report`、`set_usages` / `clear_usages` / `active_usages`、`get_usage_value` / `set_usage_value`、`get_physical_value` / `set_physical_value`、`list_reports` | Windows `hidpi.h`：`HidP_InitializeReportForID`、`HidP_SetUsages` / `HidP_UnsetUsages` / `HidP_GetUsagesEx`、`HidP_Get/SetUsageValue`、`HidP_Get/SetScaledUsageValue`、`HidP_GetCaps` |
| 字段级 | 重复 Usage、按位置批量处理 | `find_fields`、`read_field` / `write_field`、`array_selector` | hid-tools `HidField.get_values` / `fill_values` |
| 报告级 | 一次给出全部字段，重放录制数据 | `encode_report` / `decode_report` | hid-tools `create_report`、`HidP_SetData` / `HidP_GetData` |

## 描述符生成

`DescriptorBuilder::new()` 创建可链式调用的对象。`usage_page` / `usage` / `usage_range`
声明数字 Usage，`extended_usage(Usage)` 强制生成携带 page 的四字节 Usage。
`logical_range`、`report_size`、`report_count` 和 `input` / `output` / `feature` 定义字段。
Main flags 是 HID 位标志：`1` 为 Constant，`2` 为 Data Variable Absolute，
`6` 为 Data Variable Relative，`0` 为 Data Array Absolute，`0x42` 带 Null State。
bit 8（`0x100`）为 Buffered Bytes；例如 `0x102` 声明 Data Variable Buffered Bytes。

`collection` / `end_collection` 定义集合；`report_id` 定义 1..255 的 ID；
`physical_range`、`unit`、`unit_exponent` 保存元数据，`push` / `pop` 保存与恢复全局状态。
`short_item(type_code, tag, value, signed=...)` 可生成其他支持的短项，例如 String/Designator 和 Delimiter。
`type_code` 为 0 Main、1 Global、2 Local；整数采用最小的 1、2、4 字节编码。

Minimum 按有符号编码。Minimum ≥ 0 时，Linux 按无符号读取 Maximum，其他解析器可能按有符号读取，
因此构建器为 2^31 以下的 Maximum 选用两种读法结果相同的最短宽度：`logical_range(0, 255)`
生成 `15 00 26 ff 00`，而不是会触发 lint `logical_max_sign` 的 `25 ff`。
只有 2^31 及以上的无符号 Maximum 使用 4 字节，此时歧义无法避免。
Physical 范围同理；Minimum ≥ 0 而 Maximum 为负的反向范围返回 `item_value`。

首个参数错误保留至 `build()`，后续调用不再追加字节。`build()` 返回 `Result[Bytes, Diagnostic]`，
并复用 `compile_descriptor` 校验集合、栈、范围、ID 模式和资源上限。
调用方显式声明填充、ID、集合结束与位宽，当前不自动推断或优化。
对象可重复 `build()`，复制其引用会共享状态；独立描述符分别调用 `new()`。

| `We1chan/moonhid/examples` 函数 / CLI 模板 | 描述符内容 | 编码预期 |
| --- | --- | --- |
| `mouse_descriptor()` / `mouse` | 三按钮、三相对轴、填充 | `05 ff 02 fe` |
| `keyboard_descriptor()` / `keyboard` | 修饰键、六元素按键数组、五 LED Output | Input `02 00 04 06 00 00 00 00`；Output `03` |
| `gamepad_descriptor()` / `gamepad` | ID 7、十二按钮、两个 signed16 轴 | `07 01 08 00 80 ff 7f` |
| `consumer_descriptor()` / `consumer` | 媒体键：16 位 Array，Usage 0..0x3FF | 音量加 `e9 00` |
| `vendor_descriptor(report_bytes=64)` / `vendor` | 厂商 0xFF00，等长原始 Input / Output | 64 字节原始数据 |

前三个模板与仓库中独立保存的描述符逐字节比较；`consumer` 与 `vendor` 分别与 TinyUSB
`TUD_HID_REPORT_DESC_CONSUMER()`、`TUD_HID_REPORT_DESC_GENERIC_INOUT(64)` 的展开结果逐字节相同。
五个模板的 lint 结果均为空。README 的可执行示例演示生成 LED 描述符、
编码 Output、按 Usage 查询并修改 Caps Lock。

`serialize_items(parse_items(bytes))` 保留短项原始宽度、零长度项、长项和保留项的数据。
序列化不解释语义，也不保证结果可编译。短项允许 0/1/2/4 字节，长项最多 255 字节，
总描述符最多 65536 字节；短项前缀 `0xfe` 与长项标记冲突而拒绝。
`Item.offset` 不写入输出；序列化错误的 offset 是 item 索引。

## 报告初始化与 Usage 级访问

```text
list_reports(layout) -> Result[Array[ReportInfo], Diagnostic]
new_report(layout, kind, report_id) -> Result[Bytes, Diagnostic]
set_usages(layout, kind, wire, usages)   / clear_usages(...)   -> Result[Bytes, Diagnostic]
active_usages(layout, kind, wire) -> Result[Array[Usage], Diagnostic]
get_usage_value(layout, kind, wire, usage) -> Result[ReportValue, Diagnostic]
set_usage_value(layout, kind, wire, usage, value, allow_out_of_range=false)
  -> Result[Bytes, Diagnostic]
```

`list_reports` 按 Input、Output、Feature 和递增 ID 列出每个报告：载荷位数、含 ID 前缀的
`byte_length`，以及 `encode_report` 需要的值数量 `data_count`。适配层可据此分配缓冲区。
Buffered Bytes 每个 Main item 的 `data_count` 为 1，`new_report` 将整段缓冲区置零。

`new_report` 与 `HidP_InitializeReportForID` 相同：写入 Report ID；带 Null State 的 Variable
写入 Null 值，Array 元素写入空值，其他位为零。Null 值依次尝试 0、该位宽可表示的最小值和最大值，
取第一个落在 Logical 范围之外的值，例如 4 位 Hat（0..7）为 `0x0f`，8 位 -127..127 为 `0x80`。
没有可表示的范围外值时保持为零，lint `null_without_room` 会提示这种描述符。

“开关”指 Logical 0..1 的 Data Variable 元素，例如按钮和 LED。Array 元素的值落在范围外、
超出 Usage 列表或选中 Usage ID 0（各 page 的“无事件”）时视为空。
Array 的空值为 0（当 0 不选中任何 Usage 时），否则取可表示的范围外值。

- `set_usages` 对开关写 1；否则把 Usage 的选择值写入首个列出该 Usage 的 Array 中第一个空元素。
  已处于按下状态的 Usage 不变；Array 已满返回 `array_full`，与 `HidP_SetUsages` 的缓冲区不足一致。
- `clear_usages` 对开关写 0，把 Array 中等于该选择值的元素改为空值。未按下的 Usage 不变；
  Array 没有可用空值时返回 `array_no_empty`。
- `active_usages` 按字段、元素顺序列出所有按下的 Usage，每个只列一次。
- `get_usage_value` / `set_usage_value` 处理该报告中唯一带此 Usage 的 Data Variable 元素，
  范围规则同 `write_field`。多个元素共用 Usage（如厂商数据重复末项 Usage）返回 `ambiguous_usage`，
  应改用 `find_fields` 与字段级接口。
- 找不到 Usage 为 `unknown_usage`；对多值控件调用 `set_usages` 为 `value_type`，应改用 `set_usage_value`。
  Usage ID 0 不能作为 Array 按键写入。

所有写接口返回副本，出错时原报告不变；同一次调用中的多个 Usage 要么全部生效，要么返回错误。
wire 必须带所需 ID 且长度精确，规则与 `read_field` 相同。

## 物理量换算

```text
physical_value(field, logical) -> Result[Double, Diagnostic]
logical_from_physical(field, physical) -> Result[Int64, Diagnostic]
get_physical_value(layout, kind, wire, usage) -> Result[Double, Diagnostic]
set_physical_value(layout, kind, wire, usage, physical) -> Result[Bytes, Diagnostic]
```

按 HID 1.11 §6.2.2.7 的分辨率公式，先把 Logical 值线性映射到 `effective_physical_range`，
再乘以 10^Unit Exponent（未声明时为 0）。结果为双精度浮点，单位是 Unit 所在系统的基本单位，
维度由 `decode_unit` 给出。例如 Hat 0..7 映射 0..315 度时，逻辑值 2 对应 `90.0`。
Windows `HidP_GetScaledUsageValue` 以整数（`LONG`）返回结果；这里返回双精度值，并应用 Unit Exponent。

- 值在 Logical 范围外时返回 `null_value`（字段带 Null State）或 `logical_range`，
  与 `HIDP_STATUS_NULL` / `HIDP_STATUS_VALUE_OUT_OF_RANGE` 对应。
- Logical 范围退化为一点时返回 `physical_range`；反向换算还要求 Physical 两端不同。
- `logical_from_physical` 在所有后端统一按“四舍五入、0.5 远离零”取整，结果超出 Logical 范围时报错，不钳制。
  非有限输入返回 `value_range`。超过 32 位的字段没有换算，返回 `value_type`。

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
- Buffered Bytes 每个 Main item 对应 **一个** `Raw(Bytes)`，长度精确为 `bit_size * count / 8`。
  即使总宽度不超过 32 位也不能使用 `Integer`；字节内容不受 Logical 范围、Array 或 Null 标志解释。
  非字节对齐的起点或总长度在编译时返回 `buffered_alignment`。
- 默认检查 Logical 范围。Null State 允许可表示的范围外整数，解码时标记 `is_null`。
  显式 `allow_out_of_range=true` 可重放其他异常原值，但仍检查位宽与类型，不截断。
- 自动添加所需 ID；新报告的 Constant 与未用尾位为零。每报告仍遵守 65536 位上限。

Array 值为逻辑选择器。`array_selector(field, Usage)` 返回 `logical_min + Usage序列索引`，
支持多个区间和非零 Minimum；找不到 Usage 为 `unknown_usage`，超范围为 `logical_range`。
按键数组的填充与清除由上一节的 `set_usages` / `clear_usages` 处理。

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
Array 没有固定的 Usage 元素位置，应使用 `set_usages`、`array_selector` 或查看解码结果。
超宽字段 read/write 仍用 `Raw`。
Buffered Bytes 的 `element_index` 仅允许 0，read/write 一次处理整段流；`find_fields` 将首个 Usage
映射到这一引用，`get/set_usage_value` 同样传递 `Raw`。其余 Usage 保留为元数据。
缓冲区不参与 `active_usages`；`set/clear_usages` 与物理量换算不能解释其内容。

低层 `insert_bits` / `insert_bytes` 对应 `extract_bits` / `extract_bytes`，
按绝对位偏移在副本中写入，不解释 ID、Usage 或 Logical 范围。整数需显式 `signed=true`。
诊断 offset 为起始字节，非法范围与超大偏移都返回错误。

## 文件 CLI 与样例

从仓库根目录运行，native 与 Node.js 参数一致：

```sh
moon run src/cmd/moonhid --target native -- generate mouse
moon run src/cmd/moonhid --target native -- generate consumer
moon run src/cmd/moonhid --target native -- encode --kind input --id 0 examples/codec/mouse.hex examples/codec/mouse-values.json
moon run src/cmd/moonhid --target js -- encode --kind input --id 7 examples/codec/gamepad.hex examples/codec/gamepad-values.json
moon run src/cmd/moonhid --target native -- encode --kind output --id 0 examples/codec/keyboard.hex examples/codec/keyboard-led-values.json
moon run src/cmd/moonhid --target js -- encode --kind feature --id 7 examples/codec/vendor-feature.hex examples/codec/vendor-feature-values.json
moon run src/cmd/moonhid --target native -- encode --kind input --id 0 examples/codec/keyboard.hex examples/codec/keyboard-usages.json
moon run src/cmd/moonhid --target js -- encode --kind input --id 7 examples/codec/gamepad.hex examples/codec/gamepad-usages.json
```

输出依次为鼠标描述符、媒体键描述符、`05 ff 02 fe`、`07 01 08 00 80 ff 7f`、`03`、
`07 f8 ff ff ff 0f`、`02 00 04 06 00 00 00 00`、`07 01 08 00 80 ff 7f`。

`encode` 的值文件有两种形式：

- **位置形式**：JSON 数组，按字段、元素顺序列出全部 Data 元素。普通字段为整数，
  超宽字段为仅有 `hex` 字符串键的对象，例如 `[{"hex":"ff ff ff ff 01"}]` 表示一个 33 位原始元素。
  Buffered Bytes 同样使用 `hex` 对象，每个 Main item 只提供一个对象，含整段流。
  顺序、数量与 Null 规则同 `encode_report`。
- **Usage 形式**：JSON 对象，从 `new_report` 开始，依次应用三个可选数组，未提及的字段保持初始值：
  `values` 的元素为 `{"page", "id", "value"}` 或 `{"page", "id", "hex"}`，经 `set_usage_value` 写入；
  `physical` 的元素为 `{"page", "id", "value"}`，`value` 为物理量，经 `set_physical_value` 写入；
  `active` 的元素为 `{"page", "id"}`，经 `set_usages` 置为按下。`{}` 生成空闲报告。

```json
{"active": [{"page": 7, "id": 225}, {"page": 7, "id": 4}, {"page": 7, "id": 6}]}
```

上例即 Left Shift + A + C，输出 `02 00 04 06 00 00 00 00`。
CLI 采用默认严格范围，不开放异常重放开关。

成功时 stdout 为一行 hex、退出 0；输入/文件/编码错误退出 1；参数错误退出 2，错误写入 stderr。
JSON 格式错误为 `values_json`：语法、顶层类型和未知顶层键的 offset 为 0，元素格式/数值错误为数组索引；
Raw hex 错误偏移相对于该字符串；字段与 Usage 错误偏移为描述符字节位置（未定位时为 0）。
现有 inspect/decode JSON 与 lint 退出码 3 保持原约定。

MoonHID 无 ID 的 wire 不含额外 0；HIDAPI/node-hid 写接口要求首字节 ID（无 ID 时为 0），
由适配层添加。WebHID 的 ID 与 payload 分开传参。CLI 编码生成离线数据。
依据：[HIDAPI](https://github.com/libusb/hidapi/blob/master/hidapi/hidapi.h)、
[node-hid](https://github.com/node-hid/node-hid#writing-to-a-device)、[WebHID 规范](https://hid.spec.whatwg.org/)。

## 验证

生成器、编码器与模板测试检查独立预期字节、三方向、多 ID、跨字节、signed/unsigned32、
Array、Null、超宽值、最大报告与错误路径。Usage 级测试用手工推算的字节检查键盘修饰键与按键数组、
LED、Hat Null、带 ID 的 Button Array、重复 Usage 与无空值 Array；物理量测试覆盖指数、
有符号范围与取整方向。现有模糊语料加入 item 无损往返、
`decode(encode(decoded_values)) == decoded_report`、`new_report` 的 Null/零值性质，
以及 `active_usages` 只返回该报告声明过的 Usage。Constant 的原始位无需往返。

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
填入同一组字段值并比较报告字节，再独立读取 MoonHID 编码结果。覆盖五个模板的 Input，
以及键盘 LED 和厂商 Output。Usage 形式另用 hid-tools 自身的 Usage 列表和位偏移独立放置按键、
按钮与轴值，并读回按下的 Usage。
