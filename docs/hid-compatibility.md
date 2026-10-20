# MoonHID 的 HID 1.11 报告编解码兼容目标

MoonHID 的目标是 **USB-IF HID 1.11 Report Descriptor 驱动的离线 Report Protocol 编解码**。
报告级接口覆盖 Input、Output、Feature、Report ID、数值字段、Array、Constant、Null State 和
Buffered Bytes。此目标受下面明确列出的资源与语义边界约束，不表示整个 USB HID 设备栈获得认证。

Buffered Bytes 从 **0.5.0** 提供，安装入口见 [0.5.0 发布说明](release-0.5.0.md)；
**0.4.0 不支持此语义**，原发布记录保留在 [0.4.0 发布说明](release-0.4.0.md)。

## 完整报告的含义与验收目标

对一份 `compile_descriptor` 接受的描述符，选定 `(Input / Output / Feature, Report ID)` 后：

1. 编码器按描述符顺序接收该报告的全部 Data 值，生成包含所需 ID、全部字段和填充的完整报告。
   数值字段逐元素提供值；超宽 Variable 每元素提供一个 Raw；Buffered Bytes 每个 Main item 提供一段 Raw。
2. 解码器接收精确长度的完整报告，依据同一描述符提取该方向和 ID 的全部 Data 字段，
   返回整数、Usage、范围与 Null 标记，或无损提取原始字节。
3. 正确性同时以**人工指定的 wire 字节和解码语义**验收。只做本库 encode/decode 往返不足以作为兼容证据。
   [完整报告案例](report-cases.md) 提供 10 个正例和 7 个反例，清单与预期存放在
   [compatibility-cases.json](../examples/codec/compatibility-cases.json)，native 与 JS 的 CI 均执行。

Constant 位和未用尾位不属于解码后的 Data 值；新编码把这些位置零，
因此不承诺对任意非零填充执行 `encode(decode(wire))` 后逐字节不变。
需要保留原始填充时，用 `write_field` 在原报告副本中修改字段。
本目标的实现范围以下表为准，资源与语义限制也是契约的一部分。

## 标准依据与范围

依据 [USB-IF HID 1.11 原文](https://www.usb.org/sites/default/files/documents/hid1_11.pdf)：
§6.2.2.4 定义 Main 标志；§6.2.2.5 的 bit 8（印刷页 31，PDF 第 41 页）定义 Buffered Bytes；
§6.2.2.7 定义 Size、Count、ID 等 Global items；§6.2.2.8 定义 Local items；
§6.2.2.9 定义填充；§8.1–8.3 定义报告类型、ID 前缀和数值/Array 格式。
bit 8 是标准已定义能力，纳入报告编解码目标；bit 9..31 仍保留。

| HID 1.11 语义 / 条款 | 当前源码的处理与边界 | 可复核证据 |
| --- | --- | --- |
| Input、Output、Feature；§6.2.2.5、§8.1 | 同一描述符的三方向独立布局与完整报告编解码 | 案例的键盘 Input / LED Output / 厂商 Feature；[encode_test](../src/encode_test.mbt) |
| Report ID、Size、Count；§6.2.2.7、§8.2 | 方向和 ID 分开计算载荷偏移；无 ID 时不加 0，有 ID 时添加一个字节；严格检查报告长度 | 带 ID 手柄与无 ID 键盘；[report_id_test](../src/report_id_test.mbt) |
| 数值 Variable；§6.2.2.5、§8.2 | 1..32 位有符号/无符号整数；按 LSB 位序提取，支持跨字节，符号由 Logical Minimum 决定 | 鼠标负位移、signed16 手柄；[decode_test](../src/decode_test.mbt)、[encode_test](../src/encode_test.mbt) |
| 数值 Array；§6.2.2.5、§8.3 | 1..32 位选择器，按 `value - logical_min` 映射 Usage 序列；未映射值保留原数值 | 键盘六键 Array、媒体键；[values_test](../src/values_test.mbt)、[access_test](../src/access_test.mbt) |
| Constant 与填充；§6.2.2.5、§6.2.2.9 | 保留布局，新编码置零，解码省略 Constant；字段修改保留相邻原始位 | LED 的高三位为零、Feature 的低三位填充；[bits_test](../src/bits_test.mbt) |
| Null State 与 Logical 范围；§6.2.2.5、§6.2.2.7 | 解码保留越界原值并标记 Null；编码检查位宽与范围，Null 接受可表示的范围外值 | Hat 0..7 的 Null 原值 15；[encode_test](../src/encode_test.mbt) |
| 超宽 Variable；§6.2.2.7 | 大于 32 位时每元素用 Raw 与 `opaque_values` 保存位数据，不执行整数或物理量运算；超宽数值 Array 未实现 | 33 位 Feature 跨字节原始值；[opaque_test](../src/opaque_test.mbt) |
| Buffered Bytes；§6.2.2.5 bit 8 | 整个 Main item 为固定、字节对齐的 Raw 流；不解释数值、Array 或 Null | 下方三方向案例；[buffered_test](../src/buffered_test.mbt) |
| Absolute/Relative、Wrap、Linear、Preferred State、Volatile；§6.2.2.5 | 保留标志；编解码返回本报告原值，不累积相对运动、不进行环绕/非线性映射或设备状态维护 | 鼠标 Relative；[metadata_test](../src/metadata_test.mbt) |
| Physical、Unit、Unit Exponent；§6.2.2.7 | 保存元数据；通过单独物理量 API 做线性换算与十进制指数，不做单位制转换 | [编解码文档](codec.md#物理量换算)、[access_test](../src/access_test.mbt) |
| Global 栈、Collection、Local items；§6.2.2.6–8 | 支持平衡 Push/Pop、集合树、Usage 区间、String/Designator；Delimiter 按 Linux 优选分支解释，备选组保留 | [global_stack_test](../src/global_stack_test.mbt)、[local_metadata_test](../src/local_metadata_test.mbt) |
| 短项与长项；§6.2.2.2–3 | 短项编译；长项/保留项只做无损分词与序列化，编译返回明确错误 | [items_test](../src/items_test.mbt)、[builder_test](../src/builder_test.mbt) |

wire 是报告协议字节。HIDAPI/node-hid 写接口对无 ID 报告要求的额外 `00` 由传输适配层添加；
WebHID 分开提供 ID 与 payload，适配时再按这里的约定组合。具体接口见 [CLI 前缀说明](codec.md#文件-cli-与样例)。

## Buffered Bytes 契约

字节流内容由应用解释，不作为数值数量处理。MoonHID 按整个 Main item 提供一段原始字节，
保留 `00`、`ff`、字节顺序及描述符声明的 Size、Count 和全部标志。

- 长度为 `Report Size × Report Count / 8`，起始载荷位和总长度都须是 8 的倍数。
  不强制 Size 只能为 8；例如 Size 1、Count 16 与 Size 16、Count 1 都声明两字节流。
- `encode_report` 对每个非 Constant 缓冲区接受一个 `Raw(Bytes)`；
  类型不符返回 `value_type`，长度不符返回 `value_range`，不会截断或自动补齐。
- `decode_report` 输出 `buffered_values: [{field_index, bit_offset, bytes}]`；JSON 使用 `hex`。
  缓冲区不进入整数 `values` 或超宽 Variable 的 `opaque_values`。
- Logical、Physical、Unit、Array 选择器和 Null 不用于解释缓冲区内容。
  `new_report` 将缓冲区置零；按键接口跳过缓冲区，物理量换算返回 `value_type`。
- 字段读写的元素索引仅为 0；按 Usage 访问时，库将首个 Usage 与整段流关联，其他 Usage 保留为元数据。
  写入返回副本并保留 Report ID、其他字段和 Constant 位。
- 不对齐的描述符在 Main item 位置返回 `buffered_alignment`；bit 9..31 非零返回 `main_flags`。
  手工构造的无效布局在 `report_length` 等入口返回 `invalid_layout`。

## 三个可复现案例

这些是仓库自制的离线协议样例，不是设备采集结果。共用
[描述符](../examples/codec/buffered-bytes.hex)、[值文件](../examples/codec/buffered-bytes-values.json)
和 [wire 文件](../examples/codec/buffered-bytes-report.hex)。

```text
06 00 ff 09 01 a1 01       Usage Page FF00, Usage 1, Application Collection
85 05                     Report ID 5
15 00 25 01               Logical 0..1（保留元数据，不限制缓冲区字节）
75 08 95 04               Size 8, Count 4
09 02 82 02 01            Usage 2, Input, flags 0x102
09 03 92 02 01            Usage 3, Output, flags 0x102
09 04 b2 02 01            Usage 4, Feature, flags 0x102
c0                        End Collection
```

| 场景 | 输入 | 编码输出 | 解码输出 |
| --- | --- | --- | --- |
| 扫码结果等应用数据的 Input | 四字节 `4d 4f 4f 4e`（MOON） | `05 4d 4f 4f 4e` | `field_index=0`，一段四字节流 |
| 应用命令载荷的 Output | 同一 Raw 值，方向 Output | `05 4d 4f 4f 4e` | `field_index=1`，一段四字节流 |
| 应用配置载荷的 Feature | 同一 Raw 值，方向 Feature | `05 4d 4f 4f 4e` | `field_index=2`，一段四字节流 |

每个方向的载荷都是 32 位，完整 wire 为 5 字节，编码仅需一个值。
在仓库根目录执行以下命令，`kind` 分别取 `input`、`output`、`feature`：

```sh
moon run src/cmd/moonhid --target native -- encode --kind input --id 5 examples/codec/buffered-bytes.hex examples/codec/buffered-bytes-values.json
moon run src/cmd/moonhid --target native -- decode --kind input examples/codec/buffered-bytes.hex examples/codec/buffered-bytes-report.hex
moon run src/cmd/moonhid --target js -- encode --kind output --id 5 examples/codec/buffered-bytes.hex examples/codec/buffered-bytes-values.json
moon run src/cmd/moonhid --target js -- decode --kind output examples/codec/buffered-bytes.hex examples/codec/buffered-bytes-report.hex
moon run src/cmd/moonhid --target native -- encode --kind feature --id 5 examples/codec/buffered-bytes.hex examples/codec/buffered-bytes-values.json
moon run src/cmd/moonhid --target native -- decode --kind feature examples/codec/buffered-bytes.hex examples/codec/buffered-bytes-report.hex
```

Input 的 JSON 解码组件为：

```json
{"kind":"input","report_id":5,"values":[],"opaque_values":[],"buffered_values":[{"field_index":0,"bit_offset":0,"hex":"4d 4f 4f 4e"}]}
```

浏览器中粘贴同一描述符，切换三个方向并填入 wire，字段表将显示一段 Buffered Bytes。
长缓冲区显示预览，导出 JSON 保留整段数据。

## 边界与证据

每报告载荷最多 65536 位，ID 前缀另计；描述符最多 65536 字节，最多 4096 个 Main 字段和集合，
集合与 Global 栈最多 64 层。这些是实现资源上限，不是 HID 1.11 的通用上限。
数值 Array 仍限制为 1..32 位；Buffered Bytes 不受这个数值解释限制。

长项与未知保留项可无损分词、序列化，但不编译其厂商或未来扩展语义；HID 1.11 没有定义通用长项标签。
Delimiter 采用已记录的 Linux 优选分支规则，备选组保留为元数据。
核心不处理 USB 枚举、传输、Get/Set Report 请求、Boot Protocol 切换或独立 Physical Descriptor。

固定字节预期、三方向与多 ID、无 ID、混合字段、字段修改、位序与资源边界由
`src/buffered_test.mbt`、README 可执行示例和固定种子模糊测试覆盖；
CLI、bridge 与 headless Chrome 另验证公开入口，结果见 [本次验收](buffered-bytes-validation.md)。
既有七份真实描述符及 hid-tools 对照继续作为布局回归；它们不构成 Buffered Bytes 实机验收或完整协议认证。
