# HID 1.11 完整报告编解码案例

本页供初审与复现使用，兼容目标及限制见 [HID 1.11 兼容说明](hid-compatibility.md)。
以下均为离线合成案例，预期字节按描述符人工指定；硬件采集记录单独见 [Xbox 蓝牙实测](xbox-bluetooth.md)。
既有模板与 hid-tools 的独立对照见 [0.4.0 验收](codec-validation.md)，不能据此推断所有设备已兼容。

## 一条命令复核全部案例

需要 MoonBit 工具链、Node.js 22+。从仓库根目录运行：

```sh
moon update
node scripts/test-compatibility.mjs
node scripts/test-compatibility.mjs native
```

第一条验证依赖，后两条分别构建并运行 JS / native CLI。每个后端预期输出
`10 fixed-wire encode/decode cases and 7 rejection cases passed.`。
脚本检查每份值文件编码出的完整字节，并**独立解码仓库保存的报告文件**，核对全部数值、
Array/Usage、Null、超宽原始值、Buffered Bytes、方向和 ID。
预期值保存在 [案例清单](../examples/codec/compatibility-cases.json)，不是运行时由编码器产生。

## 输入文件与固定预期

表中“值文件”为编码输入，“报告”为独立解码输入；所有文件可直接点击查看。

| 案例 / 标准语义 | 描述符 | 值文件 | 完整 wire / 报告 | 解码预期 |
| --- | --- | --- | --- | --- |
| 键盘 Input，无 ID，Variable + Array | [keyboard.hex](../examples/codec/keyboard.hex) | [keyboard-usages.json](../examples/codec/keyboard-usages.json) | [`02 00 04 06 00 00 00 00`](../examples/codec/keyboard-report.hex) | 修饰键 Left Shift=1；六键 Array 选择 A、C，其他为空 |
| LED Output，Constant 填充 | [同一键盘描述符](../examples/codec/keyboard.hex) | [keyboard-led-values.json](../examples/codec/keyboard-led-values.json) | [`03`](../examples/codec/keyboard-led-report.hex) | 五个 LED 值 `[1,1,0,0,0]`，Num Lock / Caps Lock 亮 |
| 鼠标 Input，有符号 Relative | [mouse.hex](../examples/codec/mouse.hex) | [mouse-values.json](../examples/codec/mouse-values.json) | [`05 ff 02 fe`](../examples/codec/mouse-report.hex) | 按钮 `[1,0,1]`，X=-1、Y=2、滚轮=-2 |
| 手柄 Input，Report ID + signed16 | [gamepad.hex](../examples/codec/gamepad.hex) | [gamepad-values.json](../examples/codec/gamepad-values.json) | [`07 01 08 00 80 ff 7f`](../examples/codec/gamepad-report.hex) | ID=7；按钮 1/12 按下，X=-32768、Y=32767 |
| 媒体键 Input，16 位 Array | [consumer.hex](../examples/codec/consumer.hex) | [consumer-values.json](../examples/codec/consumer-values.json) | [`e9 00`](../examples/codec/consumer-report.hex) | selector=233，Usage Page=12，Usage=0xE9（音量加） |
| Feature，ID + 33 位 Raw + 非字节对齐 | [vendor-feature.hex](../examples/codec/vendor-feature.hex) | [vendor-feature-values.json](../examples/codec/vendor-feature-values.json) | [`07 f8 ff ff ff 0f`](../examples/codec/vendor-feature-report.hex) | ID=7；`opaque_values` 位偏移 3、位宽 33、hex=`ff ff ff ff 01` |
| Hat Input，Null State | [hat-null.hex](../examples/codec/hat-null.hex) | [hat-null-values.json](../examples/codec/hat-null-values.json) | [`0f`](../examples/codec/hat-null-report.hex) | Logical 0..7，原值 15，`in_logical_range=false`、`is_null=true` |
| Buffered Bytes Input | [buffered-bytes.hex](../examples/codec/buffered-bytes.hex) | [buffered-bytes-values.json](../examples/codec/buffered-bytes-values.json) | [`05 4d 4f 4f 4e`](../examples/codec/buffered-bytes-report.hex) | ID=5，`buffered_values` 字段 0 为四字节 `MOON` |
| Buffered Bytes Output | [同一描述符](../examples/codec/buffered-bytes.hex) | [同一值文件](../examples/codec/buffered-bytes-values.json) | [`05 4d 4f 4f 4e`](../examples/codec/buffered-bytes-report.hex) | 字段 1 为同一字节流，整数数组为空 |
| Buffered Bytes Feature | [同一描述符](../examples/codec/buffered-bytes.hex) | [同一值文件](../examples/codec/buffered-bytes-values.json) | [`05 4d 4f 4f 4e`](../examples/codec/buffered-bytes-report.hex) | 字段 2 为同一字节流，整数数组为空 |

## 逐步复现三种报告方向

键盘 Input 按 HID 1.11 §8.3 解释六键 Array。`02` 的 bit 1 对应 Left Shift，
第二字节为 Constant，随后 `04 06` 是 A/C 的选择器，四个零是未占用的键位。
完整长度为 8 字节，无 Report ID 前缀：

```sh
moon run src/cmd/moonhid --target js -- encode --kind input --id 0 examples/codec/keyboard.hex examples/codec/keyboard-usages.json
moon run src/cmd/moonhid --target js -- decode --kind input examples/codec/keyboard.hex examples/codec/keyboard-report.hex
```

编码预期 `02 00 04 06 00 00 00 00`。解码 `values` 的原整数依次为
`[0,1,0,0,0,0,0,0,4,6,0,0,0,0]`；索引 8、9 的 `is_array=true`，
Usage 分别为 `{"page":7,"id":4}` 和 `{"page":7,"id":6}`。

同一描述符的 LED Output 由五个 1 位 Data 值及三个 Constant 位组成，独立于 Input 的偏移与长度：

```sh
moon run src/cmd/moonhid --target js -- encode --kind output --id 0 examples/codec/keyboard.hex examples/codec/keyboard-led-values.json
moon run src/cmd/moonhid --target js -- decode --kind output examples/codec/keyboard.hex examples/codec/keyboard-led-report.hex
```

编码预期 `03`，解码五个整数为 `[1,1,0,0,0]`，高三位填充为零。
无 ID 的 Output 同样不添加 `00`；例如 HIDAPI 的写入接口前缀在适配层处理。

厂商 Feature 描述符声明 ID=7，载荷先填充 3 位，再放置 33 位 Data Variable。
载荷长 `ceil((3+33)/8)=5` 字节，加 ID 共 6 字节：

```sh
moon run src/cmd/moonhid --target js -- encode --kind feature --id 7 examples/codec/vendor-feature.hex examples/codec/vendor-feature-values.json
moon run src/cmd/moonhid --target js -- decode --kind feature examples/codec/vendor-feature.hex examples/codec/vendor-feature-report.hex
```

编码预期 `07 f8 ff ff ff 0f`；解码组件为：

```json
{"kind":"feature","report_id":7,"buffered_values":[],"opaque_values":[{"field_index":1,"element_index":0,"bit_offset":3,"bit_size":33,"hex":"ff ff ff ff 01"}],"values":[]}
```

超宽 Variable 每元素存储原始位；Buffered Bytes 按整个 Main item 存储字节流，
两者分别进入 `opaque_values` 与 `buffered_values`。Buffered Bytes 三方向的完整命令、描述符注释与 JSON 见
[固定字节流案例](hid-compatibility.md#三个可复现案例)。

## 必须拒绝的输入

同一清单还验证以下 7 项；错误写入 stderr、stdout 为空、进程退出 1：

| 输入 | 诊断代码 |
| --- | --- |
| 8 字节键盘 Input 只传 `02 00` | `report_length` |
| 无 ID 的 1 字节 LED Output 多传前导零 `00 03` | `report_length` |
| 手柄报告首字节从 ID 7 改为未声明的 8 | `unknown_report` |
| 五个 LED 只提供两个值 | `value_count` |
| Logical -127..127 的鼠标 X 写入 -128，未声明 Null | `logical_range` |
| Buffered Bytes 提供整数 `[1]` | `value_type` |
| 四字节 Buffered Bytes 只提供两个字节 | `value_range` |

上述证据验证声明范围内的离线报告格式。Output/Feature 的 USB 传输、Boot Protocol 切换与设备认证
边界见 [兼容说明](hid-compatibility.md#边界与证据)；本页不把离线输出计作实机收发。

## 本次复核记录

2026-10-20，Windows x64，固定工具链 `moon 0.1.20260920`、`moonc v0.10.14+7d59c7ec9`：

| 命令 | 本地结果 |
| --- | --- |
| `moon check --target all --deny-warn` | 四后端无警告通过 |
| `moon test --target all` | wasm / wasm-gc / JS / native 各 112/112 通过，含可执行 README |
| `node scripts/test-compatibility.mjs js` | 10 个固定报告正例、7 个错误案例通过 |
| `node scripts/test-compatibility.mjs native` | 同上，两种 CLI 的结果一致 |
| `node scripts/test-cli.mjs` | 既有 native / JS 编码、解码、生成、Unicode 路径与退出码回归通过 |
| `moon info`、`moon fmt` | 通过，公共 API 未变化 |
| `node scripts/sync-readme.mjs --check` | 两份 README 同步，184 个本地文档链接目标存在 |
