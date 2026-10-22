# 四场景演示

在仓库根目录运行：

```sh
moon run src/cmd/scenarios
```

可加 `--target wasm`、`--target wasm-gc`、`--target js` 或 `--target native`。
JS 后端需要 Node.js，native 需要 C 编译器。程序只打印由 MoonBit 核心 API 实际得到的操作结果，
不依赖文件 IO、USB 权限或网络。逻辑在 [`src/examples/scenarios.mbt`](../src/examples/scenarios.mbt)，
[`src/cmd/scenarios/main.mbt`](../src/cmd/scenarios/main.mbt) 仅负责打印。

完整预期输出：

```text
1. 键盘
生成键盘与 LED 描述符 → 05 01 09 06 a1 01 05 07 19 e0 29 e7 15 00 25 01 75 01 95 08 81 02 75 08 95 01 81 01 19 00 29 65 15 00 25 65 75 08 95 06 81 00 05 08 19 01 29 05 15 00 25 01 75 01 95 05 91 02 75 03 95 01 91 01 c0
按下 Left Shift + A → 02 00 04 00 00 00 00 00
释放 Left Shift + A → 00 00 00 00 00 00 00 00
解码 LED Output 03 → Num Lock = 1, Caps Lock = 1
2. 鼠标和手柄
解码鼠标 05 ff 02 fe → X = -1, Y = 2, Wheel = -2
Button 2 置 1，保留其他位 → 05 ff 02 fe → 07 ff 02 fe
初始化 Hat Null（ID 9）→ 09 0f
Hat 设为 90 度并读回 → 逻辑值 2, 角度 90 度, 完整报告 09 02
3. 媒体键和厂商配置
编码 Play/Pause（Usage 0x0c:0xcd）→ cd 00
33 位 Raw Feature（宽松扩展，非 HID 1.11 标准证据）→ 07 f8 ff ff ff 0f
读取厂商配置 Raw → ff ff ff ff 01
写入并读回厂商配置 → 07 90 a0 b1 c2 0b, Raw = 12 34 56 78 01
4. 固件回归
检查没有空闲值的 Hat → null_without_room
报告少一个字节 → report_length
鼠标 X 写入 -128（Logical -127..127）→ logical_range
鼠标解码后重新编码 → 05 ff 02 fe, 字节相同 = true
文件与固定预期回归 → node scripts/firmware-ci.mjs
```

## 对应的能力与验证边界

1. **键盘**：模板生成带 LED 的描述符；`new_report`、`set_usages`、`clear_usages` 操作 Shift+A；`decode_report` 解析 LED Output。
2. **鼠标与手柄**：解码负位移；`find_fields` 定位 Button 2，`write_field` 修改一个比特，结果由 `05 ff 02 fe` 变为 `07 ff 02 fe`；Hat 用 `set/get_physical_value` 在逻辑值 2 与 90 度之间换算，并经 `encode_report` 得到完整 ID 报告。
3. **媒体键与厂商配置**：Consumer 模板编码 Play/Pause；Feature 使用 `encode_report`、`read_field`、`write_field` 读写 33 位 Raw。
   33 位普通字段属于 [HID 兼容说明](hid-compatibility.md) 中的宽松扩展，不计入标准兼容证据。
4. **固件回归**：演示 lint、长度和范围诊断，以及固定报告编解码往返。
   文件与期望值回归见 [固件 CI](firmware-ci.md)，执行 `node scripts/firmware-ci.mjs`。

这些场景使用合成描述符与固定字节，不能代替真实设备通信验收。
真实描述符来源、Xbox Input 数据和完整报告案例分别见 [真实设备](real-devices.md)、[Xbox 蓝牙](xbox-bluetooth.md) 和 [报告案例](report-cases.md)。

## 验收记录

`src/examples/scenarios_test.mbt` 固定完整输出快照，CI 在四个后端分别测试并运行该入口。
快照变更需要审阅上面列出的独立字节与值预期，不能用自动更新快照替代检查。
