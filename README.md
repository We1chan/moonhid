<!-- Generated from src/README.mbt.md by node scripts/sync-readme.mjs. -->

# MoonHID

[![CI](https://github.com/We1chan/moonhid/actions/workflows/ci.yml/badge.svg)](https://github.com/We1chan/moonhid/actions/workflows/ci.yml)

**验收入口**：在仓库根目录运行 `node scripts/acceptance.mjs`（快速模式加 `--quick`）。
复现步骤、完整输出与证据：[验收说明](https://github.com/We1chan/moonhid/blob/main/docs/acceptance.md)。
交互演示：[在线检查器](https://we1chan.github.io/moonhid/)。

面向 MoonBit 的通用 HID 报告工具库：描述符生成与解析、字段布局、报告编解码、
按 Usage 读写报告、物理量换算和描述符检查。

HID 描述符告诉程序一段设备数据中的哪些位表示按键、鼠标位移或手柄摇杆。
MoonHID 将这些二进制定义转换为可复用的布局，也能从声明生成描述符、从字段值编码报告，
或直接按“按下 A 键”“X 轴设为 -1”“Hat 指向 90 度”这样的 Usage 语义读写报告。
核心为纯 MoonBit，可用于设备工具、嵌入式固件回归、自定义协议实现和浏览器分析器。
完整功能范围与各阶段验收见 [功能范围](https://github.com/We1chan/moonhid/blob/main/docs/features.md)。

## HID 1.11 兼容目标

目标为 **HID 1.11 Report Descriptor 驱动的离线 Report Protocol 编解码**：
Input / Output / Feature、Report ID、Variable、Array、Constant、Null State，
以及 Main item bit 8 的 **Buffered Bytes 固定长度字节流**。
整段字节流以一个 `Raw(Bytes)` 编码，解码放入 `buffered_values`，不套用整数范围、Array 选择器或物理量换算。
“完整报告”指一个方向和 Report ID 下的全部 Data 字段，以及 ID、Constant 和尾部填充组成的完整字节序列。
标准条款、逐项支持与限制见 [标准兼容目标](https://github.com/We1chan/moonhid/blob/main/docs/hid-compatibility.md)；
[完整报告案例](https://github.com/We1chan/moonhid/blob/main/docs/report-cases.md) 附描述符、编码输入、固定报告字节、解码预期与执行命令。

```sh
node scripts/test-compatibility.mjs
```

安装 MoonBit 与 Node.js 后，在仓库根目录执行即可复核 10 个标准范围案例、1 个宽松扩展案例和 7 个错误案例，
覆盖键盘 Input、LED Output、鼠标、带 ID 手柄、媒体键、普通 Feature、Hat Null 和三方向 Buffered Bytes。
HID 1.11 §8.4 要求普通数据字段不得跨越超过四个字节；33 位 Raw 仅作为宽松扩展回归，
不计入标准兼容证据。编译成功也不表示通过所有 HID 符合性检查。

Buffered Bytes 从 **0.5.0** 提供；0.4.0 不含此支持。报名补充说明见 [初审反馈回复](https://github.com/We1chan/moonhid/blob/main/docs/hackathon-review-response.md)。

## 使用场景

1. 自制键盘：生成按键数组和 LED 描述符，按 Usage 按下/释放按键得到 Input 报告，读取主机发来的 LED Output。
   见 [Usage 级访问](https://github.com/We1chan/moonhid/blob/main/docs/codec.md#报告初始化与-usage-级访问)。
2. 鼠标与手柄：生成并解释按钮、相对位移、摇杆轴、Hat 和带 Report ID 的报告，按物理量读写角度等数值。
   见 [物理量换算](https://github.com/We1chan/moonhid/blob/main/docs/codec.md#物理量换算)。
3. 媒体键与自定义设备：用 Consumer Control 模板生成音量、播放键报告；读写厂商 Usage、Feature 配置和超过 32 位的原始数据。
   见 [模板与值文件样例](https://github.com/We1chan/moonhid/blob/main/docs/codec.md#文件-cli-与样例)。
4. 固件与设备工具：在 CI 检查描述符、验证报告往返，在浏览器查看字段布局和真实设备输入。
   见 [固件 CI 示例](https://github.com/We1chan/moonhid/blob/main/docs/firmware-ci.md)。

## 已实现功能

仓库源码提供以下能力，接口约定及版本区别见 [编解码与生成](https://github.com/We1chan/moonhid/blob/main/docs/codec.md)：

| 能力 | 内容与入口 |
| --- | --- |
| 描述符生成 | 链式构建器 `DescriptorBuilder`；鼠标、键盘（含 LED）、手柄、媒体键、厂商数据五种模板；原始 item 序列化 `serialize_items`；CLI `generate` |
| 结构化声明（0.6.0 新增） | 独立 JSON 声明 v1，支持命名 flags、嵌套集合、显式 item 宽度和字节无损往返；`descriptor_from_declaration` / `declaration_from_descriptor`，CLI `build` / `declare`；见 [格式说明](https://github.com/We1chan/moonhid/blob/main/docs/declaration.md) |
| 描述符解析 | 十六进制输入、短项/长项分词、布局编译 `compile_descriptor`、Collection 树、Physical/Unit 元数据、版本化 JSON v2；CLI `inspect` |
| 报告编码 | `encode_report`：Input / Output / Feature、多 Report ID、整数与超宽原始值、数量/范围/Null 校验、自动写 ID 与零填充；CLI `encode` |
| 报告解码 | `decode_report`：Variable / Array、Null State、有符号与无符号、跨字节与超宽字段；CLI `decode` |
| 批量重放（0.6.0 新增） | CLI `replay` 按行解码、保留错误行号；`--expect` 比较 Usage 数值、Raw、物理量和活跃集合；[42 帧与固件示例](https://github.com/We1chan/moonhid/blob/main/docs/replay.md) |
| 帧转换（0.6.0 新增） | `transport` 纯 MoonBit 包在核心 wire、HIDAPI 缓冲区和 WebHID `(reportId, payload)` 之间转换并验证 ID/长度；[可行性与范围](https://github.com/We1chan/moonhid/blob/main/docs/hidapi.md) |
| 字段读写 | `find_fields` 按 Usage 定位字段，`read_field` / `write_field` 读写单个值并保留相邻位 |
| Usage 级访问 | 参照 Windows `hidpi.h`：`new_report` 初始化报告，`set_usages` / `clear_usages` 按下、释放按键与按钮，`get/set_usage_value`、`get/set_physical_value` 读写数值与物理量；CLI `encode` 接受按 Usage 描述的值文件 |
| 描述符检查 | `lint_descriptor` 十项规则，CLI `lint`，网页中文提示 |

核心为纯 MoonBit，支持 wasm / wasm-gc / JS / native 四种后端，运行时不依赖 USB 权限、真实设备或网络服务。
CLI 支持 native 与 Node.js；[浏览器检查器](https://we1chan.github.io/moonhid/) 直接运行 MoonBit 编译的 JS 模块。
验证包括合成的鼠标、键盘和手柄样例、[七份真实设备描述符回归](https://github.com/We1chan/moonhid/blob/main/docs/real-devices.md)、
hid-tools 0.12 独立对照（[0.4.0 验收记录](https://github.com/We1chan/moonhid/blob/main/docs/codec-validation.md)）和 [固定种子模糊测试](https://github.com/We1chan/moonhid/blob/main/docs/fuzz-validation.md)。
已发布版本见 [安装](#安装)，后续协议覆盖与实机验收计划见 [开发路线](https://github.com/We1chan/moonhid/blob/main/ROADMAP.md)。

## 与成熟 HID 库的功能对比

HID 生态的成熟库分三类：根据描述符解释与构造报告的解析库（Windows `hidpi.h`、hid-tools），
在固件中生成描述符和固定报告结构的设备端库（TinyUSB、Rust usbd-hid、Microsoft Waratah），
以及只收发原始字节的通信库（HIDAPI、node-hid）。MoonHID 属于第一类，同时提供第二类的描述符生成，
不包含第三类的设备通信。

下表以 2026-10-12 查阅的公开接口为依据；“—”表示该库不提供，需要调用方自行实现。
MoonHID 的功能状态对应 0.5.0；Buffered Bytes 从此版本新增。

| 能力 | Windows HID 解析库（C，`hidpi.h`） | hid-tools（Python） | TinyUSB（C） | usbd-hid（Rust） | HIDAPI / node-hid | MoonHID（MoonBit） |
| --- | --- | --- | --- | --- | --- | --- |
| 主要用途 | Windows 驱动与应用解析报告 | Linux HID 分析、录制与重放 | 嵌入式 USB 设备栈 | 嵌入式 USB HID 设备 | 跨平台设备通信 | 通用报告模型、编解码与生成 |
| 描述符解析、位布局 | 预解析数据、按钮/数值能力表、集合节点 | 支持 | — | — | 可读取描述符，不解析 | `compile_descriptor`，Collection 树与 Unit/Physical 元数据 |
| 描述符生成 | — | 人类可读声明转字节 | `TUD_HID_REPORT_DESC_*` 宏与 10 种模板 | `gen_hid_descriptor` 宏与预定义报告 | — | 构建器、五种模板（含媒体键、厂商数据）、原始 item 序列化 |
| 报告初始化 | `HidP_InitializeReportForID`：Null 值或零 | — | 固定报告结构体 | 固定报告结构体 | — | `new_report`：Null 值、Array 空值或零 |
| 按 Usage 置位按钮与按键数组 | `HidP_SetUsages` / `UnsetUsages` / `GetUsagesEx` | 按 Usage 名称填入数组 | 调用方填写键码，如 `tud_hid_keyboard_report` | 调用方填写 `KeyboardReport` 等字段 | — | `set_usages` / `clear_usages` / `active_usages` |
| 按 Usage 读写数值 | `HidP_GetUsageValue` / `SetUsageValue` | 按字段 `get_values` / `fill_values` | 结构体字段 | 结构体字段 | — | `get_usage_value` / `set_usage_value`；按字段 `read_field` / `write_field` |
| 物理量换算 | `HidP_GetScaledUsageValue` / `SetScaledUsageValue` | — | — | — | — | `physical_value` / `logical_from_physical` 等，含 Unit Exponent |
| 报告级编解码 | `HidP_GetData` / `SetData` | `create_report`、字段提取 | 发送固定结构体 | `AsInputReport` 序列化 | 原始字节 I/O | `encode_report` / `decode_report`，三方向、多 ID、超宽原始值、Buffered Bytes |
| 实际设备传输 | 配合 `HidD_*` 与文件 I/O | Linux hidraw / UHID | 设备端 USB 栈 | 配合 usb-device | 枚举、Input / Output / Feature | 可选 WebHID Input；核心离线处理 |
| 运行形态 | Windows 系统库 | Python / Linux 工具 | MCU 固件 | 嵌入式 Rust | 原生库 / Node.js 绑定 | wasm / wasm-gc / JS / native |

依据：[Windows hidpi.h 参考](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/hidpi/)、
[hid-tools 报告与字段实现](https://github.com/bentiss/hid-tools/blob/master/hidtools/hid.py)、
[TinyUSB hid_device.h](https://github.com/hathach/tinyusb/blob/master/src/class/hid/hid_device.h)、
[usbd-hid descriptor 模块](https://docs.rs/usbd-hid/latest/usbd_hid/descriptor/index.html)、
[HIDAPI 官方头文件](https://github.com/libusb/hidapi/blob/master/hidapi/hidapi.h)、
[node-hid 官方 API](https://github.com/node-hid/node-hid#complete-async-api)。
hid-tools 的 Python 内部 API 不保证稳定，见 [官方说明](https://github.com/bentiss/hid-tools#hidtools-python-module)。
各接口与 MoonHID 的逐一对应见 [编解码文档](https://github.com/We1chan/moonhid/blob/main/docs/codec.md)。

MoonHID 在一个库中同时提供解析库的报告访问和设备端库的描述符生成，并可在四种后端运行。
与这些库相比，MoonHID 目前不提供：原生设备枚举与 Output/Feature 收发（HIDAPI、node-hid），
完整 Usage 名称数据库（hid-tools、[Waratah](https://github.com/microsoft/hidtools#waratah)），
以及 Waratah 的描述符自动填充与优化。这些项目及验收条件见 [功能范围](https://github.com/We1chan/moonhid/blob/main/docs/features.md)。

## 安装

在现有 MoonBit 模块目录中执行：

```sh
moon add We1chan/moonhid@0.6.0
```

0.6.0 新增结构化声明 v1、批量报告重放、网页字段编辑和 transport 帧转换，保留已有编解码与 Usage 接口。
展示 JSON schema 保持 v2；声明使用独立的 v1 格式。
发布入口与安装验收见 [0.6.0 发布说明](https://github.com/We1chan/moonhid/blob/main/docs/release-0.6.0.md)。
从 0.4.0 升级时，手工构造 `DecodedReport` 的代码需增加 `buffered_values: []`。
历史版本记录保留在 [0.5.2](https://github.com/We1chan/moonhid/blob/main/docs/release-0.5.2.md)、[0.5.1](https://github.com/We1chan/moonhid/blob/main/docs/release-0.5.1.md)、[0.5.0](https://github.com/We1chan/moonhid/blob/main/docs/release-0.5.0.md)、[0.4.0](https://github.com/We1chan/moonhid/blob/main/docs/release-0.4.0.md)、[0.3.0](https://github.com/We1chan/moonhid/blob/main/docs/release-0.3.0.md) 与 [0.2.0 发布说明](https://github.com/We1chan/moonhid/blob/main/docs/release-0.2.0.md)。

在使用库的包的 `moon.pkg` 中声明导入，别名与下方 API 示例一致：

```text
import {
  "We1chan/moonhid" @moonhid,
}
```

若只在 blackbox 测试中调用，导入声明后加 `for "test"`。

## API 示例

以下代码也参与自动测试。生成 LED 描述符，编码报告，再按 Usage 定位并修改字段：

```mbt check
///|
test "README: generate encode and edit keyboard LEDs" {
  let descriptor = match
    @moonhid.DescriptorBuilder::new()
    .usage_page(1)
    .usage(6)
    .collection(1)
    .usage_page(8)
    .usage_range(1, 5)
    .logical_range(0L, 1L)
    .report_size(1)
    .report_count(5)
    .output(2)
    .report_size(3)
    .report_count(1)
    .output(1)
    .end_collection()
    .build() {
    Ok(bytes) => bytes
    Err(_) => fail("generated descriptor rejected")
  }
  let layout = match @moonhid.compile_descriptor(descriptor) {
    Ok(layout) => layout
    Err(_) => fail("layout rejected")
  }
  let wire = match
    @moonhid.encode_report(
      layout,
      @moonhid.Output,
      0,
      [1L, 1L, 0L, 0L, 0L].map(value => @moonhid.Integer(value)),
    ) {
    Ok(bytes) => bytes
    Err(_) => fail("encoding rejected")
  }
  assert_eq(wire, b"\x03")
  let caps_lock = match
    @moonhid.find_fields(layout, @moonhid.Output, 0, { page: 8, id: 2, }) {
    Ok([reference]) => reference
    _ => fail("LED Usage not found")
  }
  assert_eq(
    @moonhid.read_field(
      layout,
      @moonhid.Output,
      wire,
      caps_lock.field_index,
      caps_lock.element_index,
    ),
    Ok(@moonhid.Integer(1L)),
  )
  assert_eq(
    @moonhid.write_field(
      layout,
      @moonhid.Output,
      wire,
      caps_lock.field_index,
      caps_lock.element_index,
      @moonhid.Integer(0L),
    ),
    Ok(b"\x01"),
  )
}
```

不必知道字段位置：从空闲报告开始，按 Usage 按下、释放按键，按物理量写入 Hat 角度：

```mbt check
///|
test "README: press keys and set a hat angle by Usage" {
  let keyboard = match
    @moonhid.DescriptorBuilder::new()
    .usage_page(1)
    .usage(6)
    .collection(1)
    .usage_page(7)
    .usage_range(0xe0, 0xe7)
    .logical_range(0L, 1L)
    .report_size(1)
    .report_count(8)
    .input(2)
    .usage_range(0, 0x65)
    .logical_range(0L, 0x65L)
    .report_size(8)
    .report_count(6)
    .input(0)
    .end_collection()
    .build() {
    Ok(bytes) => @moonhid.compile_descriptor(bytes)
    Err(error) => Err(error)
  }
  let keyboard = match keyboard {
    Ok(layout) => layout
    Err(_) => fail("keyboard rejected")
  }
  let idle = match @moonhid.new_report(keyboard, @moonhid.Input, 0) {
    Ok(bytes) => bytes
    Err(_) => fail("no Input report")
  }
  let shift_a = match
    @moonhid.set_usages(keyboard, @moonhid.Input, idle, [
      { page: 7, id: 0xe1, },
      { page: 7, id: 4, },
    ]) {
    Ok(bytes) => bytes
    Err(_) => fail("keys rejected")
  }
  assert_eq(shift_a, b"\x02\x04\x00\x00\x00\x00\x00")
  assert_eq(
    @moonhid.active_usages(keyboard, @moonhid.Input, shift_a),
    Ok([{ page: 7, id: 0xe1, }, { page: 7, id: 4, }]),
  )
  assert_eq(
    @moonhid.clear_usages(keyboard, @moonhid.Input, shift_a, [
      { page: 7, id: 4, },
    ]),
    Ok(b"\x02\x00\x00\x00\x00\x00\x00"),
  )
  // Hat switch: 0..7 maps to 0..315 degrees, with a Null State for "centred".
  let hat = match
    @moonhid.DescriptorBuilder::new()
    .usage_page(1)
    .usage(5)
    .collection(1)
    .usage(0x39)
    .logical_range(0L, 7L)
    .physical_range(0L, 315L)
    .unit(0x14)
    .report_size(4)
    .report_count(1)
    .input(0x42)
    .input(1)
    .end_collection()
    .build() {
    Ok(bytes) => @moonhid.compile_descriptor(bytes)
    Err(error) => Err(error)
  }
  let hat = match hat {
    Ok(layout) => layout
    Err(_) => fail("hat rejected")
  }
  let centred = match @moonhid.new_report(hat, @moonhid.Input, 0) {
    Ok(bytes) => bytes
    Err(_) => fail("no Input report")
  }
  assert_eq(centred, b"\x0f")
  let east = match
    @moonhid.set_physical_value(
      hat,
      @moonhid.Input,
      centred,
      { page: 1, id: 0x39, },
      90.0,
    ) {
    Ok(bytes) => bytes
    Err(_) => fail("angle rejected")
  }
  assert_eq(east, b"\x02")
  assert_eq(
    @moonhid.get_physical_value(hat, @moonhid.Input, east, {
      page: 1,
      id: 0x39,
    }),
    Ok(90.0),
  )
}
```

解码一个相对轴：

```mbt check
///|
test "README: decode one relative axis" {
  let descriptor = b"\x05\x01\x09\x30\x15\x81\x25\x7f\x75\x08\x95\x01\x81\x06"
  let layout = match @moonhid.compile_descriptor(descriptor) {
    Ok(layout) => layout
    Err(_) => fail("descriptor rejected")
  }
  let report = match @moonhid.decode_report(layout, @moonhid.Input, b"\xff") {
    Ok(report) => report
    Err(_) => fail("report rejected")
  }
  assert_eq(report.values[0].value, -1L)
  assert_eq(report.values[0].usage, Some({ page: 1, id: 0x30, }))
}
```

Buffered Bytes 示例（0.5.0 起）：

```mbt check
///|
test "README: Buffered Bytes remain one application stream" {
  let descriptor = match
    @moonhid.DescriptorBuilder::new()
    .report_id(5)
    .report_size(8)
    .report_count(4)
    .input(0x102)
    .build() {
    Ok(bytes) => bytes
    Err(_) => fail("descriptor rejected")
  }
  let layout = match @moonhid.compile_descriptor(descriptor) {
    Ok(layout) => layout
    Err(_) => fail("layout rejected")
  }
  assert_eq(
    @moonhid.encode_report(layout, @moonhid.Input, 5, [@moonhid.Raw(b"MOON")]),
    Ok(b"\x05MOON"),
  )
  let report = match
    @moonhid.decode_report(layout, @moonhid.Input, b"\x05MOON") {
    Ok(report) => report
    Err(_) => fail("report rejected")
  }
  assert_eq(report.values, [])
  assert_eq(report.buffered_values[0].bytes, b"MOON")
}
```

主要接口：

| 类别 | 接口 | 用途 |
| --- | --- | --- |
| 描述符生成 | `DescriptorBuilder` | 生成描述符；Usage、范围、集合、ID、三方向、Physical/Unit、Push/Pop；`build()` 校验 |
| | `serialize_items` | 原始短项/长项序列化，保留宽度与数据，可与分词无损往返 |
| 描述符解析 | `parse_hex` | 严格解析连续或 ASCII 空白分隔的十六进制字节对 |
| | `parse_items` | 保留 item 类型、tag、原始数据和字节位置 |
| | `unsigned_value` / `signed_value` | 小端短项数值，完整保留 32 位范围 |
| | `compile_descriptor` | 计算 Main 字段、集合树、元数据、报告 ID 与位偏移 |
| | `field_usage` | 按序查询 Usage；Variable 越界重复最后一项，Array 越界返回 None |
| 报告编码 | `list_reports` | 列出每个报告的方向、ID、字节长度与编码所需值数量 |
| | `new_report` | 生成空闲报告：写入 ID，Null State 字段取 Null 值，Array 取空值，其余为零 |
| | `encode_report` | 根据布局编码 `Integer` / `Raw` 值，校验数量、类型、范围，自动写 ID 与零填充 |
| 报告解码 | `report_length` | 查询指定方向和 ID 的完整报告字节长度 |
| | `decode_report` | 校验长度并返回变量值、数组 Usage、Null State、超宽值与 Buffered Bytes |
| 字段读写 | `find_fields` / `array_selector` | 查询 Variable Usage 的全部字段引用，或把 Array Usage 转为逻辑选择器 |
| | `read_field` / `write_field` | 按字段和元素索引读写单个值，包含报告长度与归属校验 |
| Usage 级访问 | `set_usages` / `clear_usages` / `active_usages` | 按 Usage 按下、释放、列出按钮与按键；自动处理按键数组的空位 |
| | `get_usage_value` / `set_usage_value` | 按 Usage 读写单个数值控件，例如摇杆轴 |
| | `get_physical_value` / `set_physical_value` | 按 Usage 读写物理量，例如 Hat 角度 |
| 物理量与单位 | `physical_value` / `logical_from_physical` | Logical 值与物理量互换，应用 Physical 范围和 Unit Exponent |
| | `decode_unit` / `effective_physical_range` | 展开单位维度，并应用 HID 物理范围缺省规则 |
| 描述符检查 | `lint_descriptor` | 检查可编译描述符的映射与结构风险，规则见 [lint 说明](https://github.com/We1chan/moonhid/blob/main/docs/lint.md) |
| JSON 导出 | `descriptor_to_json` / `layout_to_json` / `report_to_json` | 导出版本化描述符与布局、解码组件 |
| | `lint_to_json` | 导出含级别、item 偏移与可选字段索引的 lint 组件 |
| 位操作 | `extract_bits` | 提取跨字节、带符号或无符号的位字段 |
| | `extract_bytes` | 按 LSB 位序提取原始字节，支持非字节对齐 |
| | `insert_bits` / `insert_bytes` | 在副本中写入整数或原始位字段，保留其他位 |

完整类型签名见 [pkg.generated.mbti](https://github.com/We1chan/moonhid/blob/main/src/pkg.generated.mbti)。

## 快速运行

安装 [MoonBit 官方工具链](https://www.moonbitlang.com/download/) 后：

```sh
git clone https://github.com/We1chan/moonhid.git
cd moonhid
moon run src/cmd/main
moon run src/cmd/scenarios
moon run src/cmd/moonhid --target native -- generate keyboard
moon run src/cmd/moonhid --target js -- build examples/declarations/keyboard.json
moon run src/cmd/moonhid --target js -- declare examples/codec/keyboard.hex
moon run src/cmd/moonhid --target native -- encode --kind input --id 0 examples/codec/keyboard.hex examples/codec/keyboard-usages.json
```

`src/cmd/main` 打印三个设备样例的字段偏移、数字 Usage 和原始整数值。其中鼠标样例
`05 ff 02 fe` 表示按钮 1 和 3 按下，X/Y/滚轮变化分别为 `-1 / 2 / -2`；
手柄样例带 Report ID `7`，两个 16 位轴分别为 `-32768 / 32767`。
`generate keyboard` 输出带 LED Output 的键盘描述符，与 `examples/codec/keyboard.hex` 逐字节相同；
`encode` 读取值文件，按 Usage 按下 Left Shift、A 和 C，输出 Input 报告 `02 00 04 06 00 00 00 00`。

`moon run src/cmd/scenarios` 按顺序演示键盘、鼠标与手柄、媒体键与厂商配置、固件回归四个场景。
全部业务操作由 MoonBit 实际执行，完整固定输出与各场景说明见 [四场景演示](https://github.com/We1chan/moonhid/blob/main/docs/scenarios.md)。
该入口不依赖文件、设备或网络，wasm / wasm-gc / JS / native 均可运行，输出快照参与四后端测试。

## 文件命令行工具

CLI 提供 native 与 Node.js 后端，描述符与报告文件按 UTF-8 十六进制文本读取：

```sh
moon run src/cmd/moonhid --target native -- generate keyboard
moon run src/cmd/moonhid --target native -- inspect descriptor.hex
moon run src/cmd/moonhid --target js -- inspect descriptor.hex
moon run src/cmd/moonhid --target native -- lint descriptor.hex
moon run src/cmd/moonhid --target native -- encode --kind output --id 0 examples/codec/keyboard.hex examples/codec/keyboard-led-values.json
moon run src/cmd/moonhid --target native -- encode --kind input --id 0 examples/codec/keyboard.hex examples/codec/keyboard-usages.json
moon run src/cmd/moonhid --target js -- encode --kind feature --id 7 examples/codec/vendor-feature.hex examples/codec/vendor-feature-values.json
moon run src/cmd/moonhid --target native -- decode --kind input descriptor.hex report.hex
moon run src/cmd/moonhid --target js -- replay --kind input examples/firmware-ci/descriptor.hex examples/firmware-ci/frames.txt --expect examples/firmware-ci/expected.jsonl
```

| 子命令 | 作用与输出 |
| --- | --- |
| `generate` | 从 MoonBit 构建器生成 mouse / keyboard / gamepad / consumer / vendor 描述符，stdout 为十六进制 |
| `build` / `declare`（0.6.0 新增） | 声明 JSON v1 → 描述符十六进制，或从描述符导出带原始宽度的声明；不与展示 JSON v2 混用 |
| `inspect` | 输出完整描述符 JSON v2，其中 `lints` 数组列出检查结果 |
| `lint` | 每条检查结果输出一行，例如 `warning usage_count @18: ...`；没有提示时 stdout 为空，规则见 [lint 说明](https://github.com/We1chan/moonhid/blob/main/docs/lint.md) |
| `encode` | 按值文件编码 Input / Output / Feature 报告，stdout 为十六进制 |
| `decode` | 输出带 `schema_version: 2` 的 `wire_hex` / `decoded` 组件；报告文件应包含所需的 Report ID 前缀 |
| `replay`（0.6.0 新增） | 每行一帧 hex，允许空行与 `#` 注释；stdout 为带原文件行号的 JSONL，`--expect` 按 Usage 逐帧断言，见 [重放说明](https://github.com/We1chan/moonhid/blob/main/docs/replay.md) |

`encode` 接受两种值文件：按字段、元素顺序排列的 JSON 数组，例如 `[1, 1, 0, 0, 0]`
编码键盘 LED Output 为 `03`，超宽字段用 `{"hex": "ff ff ff ff 01"}`；或按 Usage 描述的 JSON 对象，
例如 `{"active": [{"page": 7, "id": 225}, {"page": 7, "id": 4}]}` 表示按下 Left Shift 与 A，
未提及的字段保持空闲值。示例与完整格式见 [codec 文档](https://github.com/We1chan/moonhid/blob/main/docs/codec.md)。

`--kind` 可以是 input、output、feature；`encode` 的 `--id 0` 用于不带 ID 的报告。
成功时 stdout 只含 JSON、十六进制或检查结果；错误写入 stderr，格式为 `code @offset: message`。
退出码：0 表示成功，1 表示文件、输入或诊断错误，2 表示参数错误；
`lint` 存在 Warning 或 `replay` 期望不匹配时退出 3；只有 Info 时 `lint` 仍退出 0，`inspect` 有 Warning 时也退出 0。

固件仓库的 CI 可以构建 native 可执行文件，检查导出的描述符，并根据退出码判断是否需要审阅：

```sh
moon build src/cmd/moonhid --target native --release
./_build/native/release/build/cmd/moonhid/moonhid.exe lint descriptor.hex
```

文件读取采用 [moonbitlang/x](https://github.com/moonbitlang/x) 0.5.5（Apache-2.0）。
该 fs 包具有四后端实现，但本 CLI 的进程参数与 stderr 适配限定为 native/Node JS；
核心解析库与浏览器桥接不导入 fs/sys，继续支持四后端。
`node scripts/test-cli.mjs` 会运行两个真实 CLI 进程，检查 Unicode/空格路径和退出码。

## 浏览器检查器

检查器用于分析描述符与报告：解析、位布局、解码、lint 与 JSON 导出。
0.6.0 新增报告初始化、字段编辑与 HEX 导出，Input / Output / Feature 均可离线构造；
操作示例见 [网页报告编辑](https://github.com/We1chan/moonhid/blob/main/docs/browser-editor.md)。描述符生成和按 Usage 编码还可通过库与 CLI 使用。

直接打开 [在线检查器](https://we1chan.github.io/moonhid/)。
[Release](https://github.com/We1chan/moonhid/releases/latest) 提供编译好的离线包：
解压后只需 Node.js 22+，Windows 双击 `start-inspector.cmd`，
其他系统运行 `node scripts/serve-offline.mjs`，不需要 MoonBit 或 Python。

从源码运行：

安装 MoonBit、Node.js 22+ 和 Python 3 后：

```sh
node scripts/build-web.mjs
python3 scripts/serve-web.py
```

打开 <http://127.0.0.1:8765/>。macOS 可直接双击仓库根目录的
[start-inspector.command](https://github.com/We1chan/moonhid/blob/main/start-inspector.command)，自动构建并打开浏览器；
终端中按 `Ctrl+C` 关闭服务。端口被其他程序占用时，可设置 `MOONHID_PORT=8766`。

界面分为三栏：左侧是描述符编辑器和逐项注释的 Items 列表，中间是报告选择、原始报告输入、
按字节排列的位布局和解码值表，右侧是字段编辑器、详情与 Collection 树。窄屏时按同一顺序单列排列，
浅色与深色主题跟随系统设置。

点击鼠标、键盘或手柄载入合成样例。粘贴自己的描述符后会自动解析；在报告标签中选择
Input / Output / Feature 与 Report ID，填入完整报告后自动解码，`Ctrl/⌘ + Enter` 立即执行。
每个报告的输入分别保留；键盘切换到 Output 后可点「载入样例报告」，检查 `03` 的 LED 值。
位布局、解码值表、Items 和字段详情相互关联：选择字段会在两个十六进制编辑器中标出对应的
描述符 item 与报告字节，并在解码值表中显示目标字段所在页；当前页已有该字段时保留页码。
点击 Global / Local item 或 Collection 会标出它们在描述符中的字节范围。
十六进制输入错误会在编辑器中标红，并给出字符或字节偏移；首字节 Report ID 与所选报告不一致时，
可以一键切换到对应报告。

点击「初始化报告」创建当前方向与 ID 的报告，再在值表选择数据元素，在右侧填写十进制整数或原始十六进制字节，
点击「写入报告」同步更新报告与解码结果。写入保留相邻字段、Constant、未用尾位和 Report ID；
范围、位宽或字节长度不符时保留原报告并显示错误。多元素字段可直接选择元素索引，Buffered Bytes 整段编辑。
「导出报告 HEX」保存当前完整报告，含所需 ID 前缀；「导出 JSON」同时保存描述符与解码值。
实时 Input 接收期间需先断开再编辑报告。网页构造与导出字节，设备 Output/Feature 发送仍见 [开发路线](https://github.com/We1chan/moonhid/blob/main/ROADMAP.md)。

左侧中文 lint 面板区分 Warning / Info，可筛选、分页并定位 item 与字段。
编译成功但有 Warning 时仍可解码；未产生提示不等于协议认证。
中栏「发现问题 → 修改 → 验证」案例演示 Hat Null 范围修正和同一报告的解码变化。
固件团队可复制 [完整 CI 示例](https://github.com/We1chan/moonhid/blob/main/docs/firmware-ci.md)，检查描述符及保存的报告预期值。

页面不加载外部脚本或 CDN，数据只在页面内处理。本地服务只监听 `127.0.0.1`。
解码值表每页最多 200 行，Items 每页最多 500 项，位布局最多展示前 256 个字节，Collection 树最多列出 500 个；
分页表格、报告输入和 JSON 保留完整数据。位布局每行一个字节、左侧为最高位，载荷按 HID 的 LSB 位序解释。
「导出 JSON」保存当前描述符及已成功解码的报告，格式见 [JSON v2](https://github.com/We1chan/moonhid/blob/main/docs/json-v2.md)。
生成的 `web/moonhid-core.js` 不提交，始终从仓库中的 MoonBit 源码构建。

## WebHID 实时输入

在 Chromium 中使用 HTTPS 或 `http://127.0.0.1` 打开检查器，先粘贴并解析描述符，
再点「连接 HID」选择设备。WebHID 不提供原始描述符，需要按
[读取方法](https://github.com/We1chan/moonhid/blob/main/docs/real-devices.md#自行读取描述符) 自行获取。
Chrome 会屏蔽键盘和鼠标的受保护 Collection；手柄与厂商自定义 Collection 是否可用由浏览器决定。

页面接收 Input 报告，非零 `reportId` 补回数据前缀后交给 MoonBit 解码。
每帧显示最新报告，计数包含收到的全部事件；不同 ID 自动切换到对应 Input 布局。
同一报告的刷新保留字段按钮和键盘焦点，可以在接收过程中选择字段和定位错误。
点「断开」或拔出设备会停止监听，之后可继续离线编辑。

「与浏览器 collections 对照」比较方向/ID/载荷位数，以及 Main 字段的 size、count、flags、
Logical 和 Usage。WebHID 顶层 reports 已包含嵌套集合字段，避免重复计数。
缺少报告可能来自浏览器保护规则或粘贴的描述符不匹配，不应直接视为 MoonHID 解析错误。
WebHID 不暴露完整原始项，String/Designator/Delimiter 等元数据不参与此对照。

[Xbox 蓝牙实测](https://github.com/We1chan/moonhid/blob/main/docs/xbox-bluetooth.md) 已记录 42 条实际 Input，验证 A 状态、左轴两端和回中，
并重放原始数据。检查器提供独立的「手柄实机验证」入口：浏览器可见字段生成参考布局，
逻辑范围不完整时需明确选择原始位值模式；不会冒充原始设备描述符。
自动测试用模拟 HIDDevice 覆盖前缀、DataView 子视图、连接/断开、热拔插和连接中取消；
实机验收以上述 Xbox 蓝牙记录为准。

## 支持范围与边界

- 描述符 lint 在布局编译成功后运行，Warning / Info 不改变编译结果。
  规则包括 `logical_max_sign`、`physical_max_sign`、`null_without_room`、`usage_count`、`missing_usage`、
  `unaligned_report`、`field_outside_application`、`collection_without_usage`、
  `multiple_applications_without_report_id`、`report_id_shared_across_applications`，
  触发条件与级别是契约，见 [规则依据与限制](https://github.com/We1chan/moonhid/blob/main/docs/lint.md)。JSON v2、bridge、CLI 与中文网页面板均已接入。
- 支持 Input / Output / Feature、Usage / Usage 范围 / 32 位扩展 Usage、
  Logical / Physical 范围、Unit / Unit Exponent、Report Size / Count / ID、Global Push / Pop，
  并保留 Collection 的类型、Usage、父索引与字段所属集合。
- 零长度短项的数据按 0 解释；零长度 Collection 表示 Physical，零长度 Main flags 表示 0。
  Report ID 0 和 Report Count 0 仍拒绝；Report Size 0 不能用于定义字段。
- 变量字段按声明顺序对应 Usage，数量不足时重复最后一个 Usage。
  Usage 按区间保留，不展开大范围；数组值按 `value - logical_min` 索引 Usage 序列；未映射的值保留原值。
- 保留填充字段的布局，解码输出省略 Constant 字段；超宽值存入 `opaque_values`，不进行整数或 Usage 索引解释；保留超出逻辑范围的值，
  通过 `in_logical_range` 和 `is_null` 区分异常值与声明的 Null State。
- 字段位偏移从报告载荷的第 0 位计算，不含 Report ID 字节；解码输入必须包含
  描述符要求的 ID 前缀，并且长度必须精确匹配，不能带额外传输层前缀或尾部字节。
- 编码按非 Constant 字段、元素顺序要求完整值列表，省略填充字段；不会截断、钳制或自动补齐缺少的数据。
  1..32 位用 `Integer`，超宽字段用 `Raw`，末字节高位须为零。默认检查 Logical 范围，
  声明 Null State 时接受可表示的范围外值；显式 `allow_out_of_range=true` 可重放其他范围外原值。
  新报告的 Constant 和未用尾位为零；`write_field` 保留它们及所有相邻位。
- Buffered Bytes 按整个 Main 字段消费一个 `Raw`，长为 `Report Size × Report Count / 8`；
  起始偏移与总长度必须按 8 位对齐，否则返回 `buffered_alignment`。
  解码输出 `buffered_values`，保留 `00`、`ff` 和顺序；不解释 Logical、Physical、Array 或 Null。
  字段读写使用元素索引 0；按 Usage 访问整段缓冲区时使用首个 Usage。
- 构建器为有状态、可链式调用的对象，第一项参数错误保留至 `build()`。
  调用方显式定义 Report ID、填充与集合结束；当前不自动分配 ID、补齐字节、推断位宽或优化全局状态。
  Minimum ≥ 0 时 Maximum 采用有符号、无符号读法一致的最短宽度（255 生成 `26 ff 00`），
  只有 2^31 及以上的值使用 4 字节。原始序列化可保存未知项，生成可编译描述符须通过 `build()`。
- String / Designator 索引和区间保存为字段与 Collection 元数据，随后清空本地状态；
  Delimiter 按 Linux 的公共 Usage + 第一个集合规则解码，后续集合保存在 `alternate_usages`。
  嵌套、无开启的关闭和未闭合返回 `delimiter`；索引范围错误返回 `local_range`，
  每类索引最多 1024 段（`local_limit`），优选与备选 Usage 合计最多 1024 段（`usage_limit`）。
  长项仅支持原始分词，布局编译会拒绝；保留字也明确报错。Buffered Bytes 的 bit 8 已支持，bit 9..31 仍为保留位。
  Physical 范围和 Unit 全局项允许存在，
  解码返回原始整数；需要时用 `physical_value` 等接口按 Physical 范围与 Unit Exponent 换算为双精度物理量。
  核心保留数字 Usage；页面只补充常见 Usage 名称，不是完整 HID Usage Tables 数据库。
- Usage 级接口把 Logical 0..1 的 Data Variable 元素视为开关；Array 元素在范围外、超出 Usage 列表或选中
  Usage ID 0 时视为空。多个元素共用同一 Usage 时返回 `ambiguous_usage`，Array 已满返回 `array_full`；
  完整规则见 [编解码文档](https://github.com/We1chan/moonhid/blob/main/docs/codec.md#报告初始化与-usage-级访问)。
- 限制：描述符最多 65536 字节，最多 4096 个 Main 报告字段，整数每值 1..32 位，超过 32 位的 Data Variable 字段按原始字节解码，
  Constant 字段也允许超宽；Data Array 位宽仍限 1..32。
  超宽普通字段及跨越超过四个字节的普通元素属于宽松扩展，超出 HID 1.11 §8.4，
  不计入标准兼容证据；编译器当前不拒绝这些布局，lint 也不是完整的 HID 符合性检查器。
  每报告最多 65536 位，字段元素数量由报告总位数约束（最多 65536 个值），Usage 最多 1024 个区间，单区间可覆盖同一 page 的全部 65536 个 ID，
  Collection 最多 4096 项，Collection 与 Global 栈深度最多 64。Global Push/Pop 要求平衡。
  Unit Exponent 支持 -8..7 的四位编码及常见符号扩展编码；保留 Unit 的系统与保留位。
  Physical 缺少任一端点或两端均为 0 时，有效范围采用 Logical 范围，原声明仍可查询。
- 核心库处理离线字节；网页可选 WebHID 只接收 Input，不发送 Output/Feature。
  不提供驱动安装或 Boot Protocol 切换；合成样例测试不能代表已兼容所有 HID 设备。

错误通过 `Result[..., Diagnostic]` 返回。二进制输入的 `offset` 是字节偏移，
十六进制文本的 `offset` 是 UTF-16 索引。`parse_hex` 不接受 `0x` 前缀、逗号或
字节对内的空白，`05 01`、`0501` 均可。

## 项目目录

```text
moonhid/
├── moon.mod                 # 模块配置，source = "src"
├── src/                     # MoonBit 源码根目录
│   ├── *.mbt、*_test.mbt    # 核心库及同包测试
│   ├── moon.pkg             # 核心包依赖
│   ├── pkg.generated.mbti   # 核心包公开接口
│   ├── README.mbt.md        # 本文，API 示例参与自动测试
│   ├── browser/             # 浏览器 JS 桥接
│   ├── cmd/                 # 文件 CLI 与演示入口
│   └── examples/            # MoonBit 合成设备样例包
├── examples/                # 设备回归数据与固件 CI 示例
├── web/                     # 检查器页面
├── scripts/                 # 构建、验收与打包脚本
├── docs/                    # 协议说明与验收记录
└── README.md                # 从可执行 README 生成，链接按仓库根目录改写
```

包名仍为 `We1chan/moonhid`；`src/` 是源码根目录，不属于导入路径。
MoonBit 按目录组织包，因此 `*_test.mbt` 与被测源码保留在同一个包目录中。
以下开发命令均在仓库根目录执行；指定文件或入口包时使用实际路径，
例如 `moon test src/layout_test.mbt` 和 `moon run src/cmd/main`。

## 开发

本机验证工具链：`moon 0.1.20260920`、`moonc v0.10.14+7d59c7ec9`。
稳定 CI 固定 `toolchain.json` 中的官方工具链，验证四种后端，
另设最新工具链兼容任务；日志记录完整版本：

```sh
moon check --target all --deny-warn
moon build
moon test
moon test --target native
moon test --target js # 需要 Node.js
node scripts/build-web.mjs
node scripts/test-web.mjs
node scripts/test-usability.mjs
node scripts/test-compatibility.mjs
node scripts/firmware-ci.mjs
moon info
moon fmt --check
node scripts/sync-readme.mjs --check
```

修改 `src/README.mbt.md` 后运行 `node scripts/sync-readme.mjs`，同步仓库首页并改写相对链接。
`moon.mod` 以生成的根 `README.md` 作为发布文档；Mooncakes 同时展示模块和包内可执行 README，
因此源 README 的所有跨页链接均使用 GitHub 明确地址，避免依赖展示平台的相对路径基址。
CI 检查发布文档入口、跨页链接地址、两份 README 一致及文档文件和锚点；发布后运行
`node scripts/check-public-docs.mjs`，验证线上页面实际生成的文档链接。

CI 的 JS 任务也构建浏览器模块，并验证三个样例、LED Output、多 ID、Feature、
Physical/Unit、完整 uint32 和错误路径。CLI 进程回归额外验证五种模板的生成、编码与解码、Usage 形式的值文件、LED Output 和超宽 Feature；
hid-tools 对照还独立放置按键、按钮与轴值，检查 Usage 级编码。
独立 hid-tools 对照与 headless Chrome DOM 检查也纳入 JS CI，验证真实描述符布局与界面。
四后端还运行固定种子的随机字节、结构化有效描述符与真实描述符突变；
语料、资源边界及解码性质见 [模糊测试验收](https://github.com/We1chan/moonhid/blob/main/docs/fuzz-validation.md)。
浏览器人工和自动验收记录见
[检查器验收](https://github.com/We1chan/moonhid/blob/main/docs/inspector-validation.md)。[性能基准](https://github.com/We1chan/moonhid/blob/main/docs/performance.md) 记录实际来源
描述符与资源上限报告的 bridge/JSON 耗时，每次 CI 保存测量结果。

## 协议与参考

- [USB-IF HID 1.11](https://www.usb.org/document-library/device-class-definition-hid-111)
- [Linux 内核：HID report descriptors](https://docs.kernel.org/hid/hidintro.html)

本项目按公开协议独立实现。仓库内的合成设备样例用于测试声明的支持范围。
采用 Apache-2.0 许可证，见 [LICENSE](https://github.com/We1chan/moonhid/blob/main/LICENSE)。

代码、测试与文档在 AI 编程工具协助下完成，分工与质量控制见 [AI 协作说明](https://github.com/We1chan/moonhid/blob/main/docs/ai-collaboration.md)。

## 比赛验收对照

下表列出每项标准对应的可核对证据。

| 标准 | 本项目的做法与证据 |
| --- | --- |
| MoonBit 为主 | 核心解析、编解码、lint、构建器、CLI、场景逻辑和浏览器桥接使用 MoonBit；JS 处理界面、设备适配和验收编排。[设计说明](https://github.com/We1chan/moonhid/blob/main/docs/design.md)、[源码行数统计命令](https://github.com/We1chan/moonhid/blob/main/docs/acceptance.md#源码统计) |
| 仓库公开 | 公开保留开发与交付记录。[提交历史](https://github.com/We1chan/moonhid/commits/main/)、[Issues 与里程碑](https://github.com/We1chan/moonhid/milestone/1)、[PR](https://github.com/We1chan/moonhid/pulls?q=is%3Apr)、[Release](https://github.com/We1chan/moonhid/releases) |
| 能够运行 | 一键复现四后端、CLI、网页、离线包和场景演示；可选检查缺依赖明确跳过。[验收说明](https://github.com/We1chan/moonhid/blob/main/docs/acceptance.md)、[CI](https://github.com/We1chan/moonhid/actions/workflows/ci.yml) |
| 工作有效 | 仓库创建于 2026-10-01，已有 0.2.0 至 0.6.0 的版本记录，新增工作通过独立 Issue/PR 跟踪。[版本记录](https://github.com/We1chan/moonhid/releases)、[四场景示例](https://github.com/We1chan/moonhid/blob/main/docs/scenarios.md) |
| 开源合规 | Apache-2.0；核心按公开协议独立实现，记录模板参考和真实描述符来源。[LICENSE](https://github.com/We1chan/moonhid/blob/main/LICENSE)、[真实设备来源](https://github.com/We1chan/moonhid/blob/main/docs/real-devices.md) |
| AI 可解释 | 公开参赛者与 AI 工具的分工、质量控制和纠错记录，核心设计有独立说明。[AI 协作说明](https://github.com/We1chan/moonhid/blob/main/docs/ai-collaboration.md)、[设计说明](https://github.com/We1chan/moonhid/blob/main/docs/design.md) |
