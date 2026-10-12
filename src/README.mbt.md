# MoonHID

[![CI](https://github.com/We1chan/moonhid/actions/workflows/ci.yml/badge.svg)](https://github.com/We1chan/moonhid/actions/workflows/ci.yml)

面向 MoonBit 的通用 HID 报告工具库：描述符生成与解析、字段布局、报告编解码、字段读写和描述符检查。

HID 描述符告诉程序一段设备数据中的哪些位表示按键、鼠标位移或手柄摇杆。
MoonHID 将这些二进制定义转换为可复用的布局，也能从声明生成描述符、从字段值编码报告，
或在已有报告中修改单个字段。核心为纯 MoonBit，可用于设备工具、嵌入式固件回归、
自定义协议实现和浏览器分析器。完整功能范围与各阶段验收见 [功能范围](../docs/features.md)。

## 预期使用场景

1. 自制键盘：生成按键数组和 LED 描述符，编码 Output 报告，按 LED Usage 查询并修改位值。
2. 鼠标与手柄：生成并解释按钮、相对位移、摇杆轴和带 Report ID 的报告，制作输入回归数据。
3. 自定义设备协议：读写厂商 Usage，编码 Feature 配置和超过 32 位的原始数据字段。
4. 固件与设备工具：在 CI 检查描述符、验证报告往返，在浏览器查看字段布局和真实设备输入。

## 当前状态

仓库版本为 **0.4.0，尚未发布到 mooncakes.io**：新增报告编码、描述符构建器、原始 item 序列化、
字段读写与 Usage 查询，以及 CLI `encode` / `generate`。这些新接口请从本仓库源码运行；
安装已发布版本尚不包含它们，使用约定见 [编解码与生成](../docs/codec.md)。
本次四后端与 hid-tools 独立对照结果见 [0.4.0 验收记录](../docs/codec-validation.md)。

0.3.0 已发布到 mooncakes.io，并通过独立项目的四后端安装验收。JSON schema 保持 v2，已有 lint API、CLI 与中文网页提示，见
[0.3.0 发布说明](../docs/release-0.3.0.md)。0.2.0 的独立四后端安装验收仍保留在
[历史发布说明](../docs/release-0.2.0.md)。核心库为纯 MoonBit，
已实现十六进制输入、短项/长项分词、布局编译、Collection 层级、Physical/Unit 元数据和报告解码。
仓库提供合成的鼠标、键盘和手柄样例，以及 [七份真实设备描述符回归](../docs/real-devices.md)，运行时不依赖 USB 权限、真实设备或网络服务。
浏览器检查器直接运行 MoonBit 编译的 JS 模块，提供字段布局、解码值与版本化 JSON 导出。
后续协议覆盖与实机验收计划见 [开发路线](../ROADMAP.md)。

## 与成熟 HID 库的功能对比

下表以 2026-10-12 查阅的公开接口为依据；“调用方处理”表示库传递原始报告，字段解释需要额外实现。
MoonHID 的功能状态对应仓库 0.4.0 源码。

| 能力 | HIDAPI（C） | node-hid（JS） | hid-tools（Python） | Waratah（C#） | MoonHID（MoonBit） |
| --- | --- | --- | --- | --- | --- |
| 主要用途 | 跨平台设备通信 | Node.js 设备通信 | Linux HID 分析、录制与重放 | 固件描述符创作 | 通用报告模型、编解码与生成 |
| 二进制描述符解析、位布局 | 调用方处理；可获取描述符 | 调用方处理 | 支持 | 从声明源编译模型 | 支持，明确协议子集 |
| 描述符生成 | 调用方处理 | 调用方处理 | 人类可读声明转字节 | 声明编译、优化、自动填充 | 构建器、三种设备模板、原始 item 序列化 |
| 报告编码与解码 | 原始字节 I/O | 原始字节 I/O | `create_report`、字段提取/填入 | 可生成 C++ 报告结构 | Input / Output / Feature，整数与原始字节 |
| 按字段读写 | 调用方处理 | 调用方处理 | `get_values` / `fill_values` | 通过生成结构访问 | `read_field` / `write_field`，保留相邻位 |
| Usage 查询与数组映射 | 设备 Usage 信息 | 设备 Usage 信息 | Usage 名称及数组映射 | 公共 Usage 数据库 | 数字 Usage 查询、Array 选择器；网页补充常见名称 |
| 实际设备传输 | 枚举、Input / Output / Feature | 枚举、Input / Output / Feature | Linux hidraw / UHID | 不提供传输 | 可选 WebHID Input；核心离线处理 |
| 运行形态 | 操作系统原生库 | Node.js 与原生绑定 | Python / Linux 工具 | .NET 工具与库 | wasm / wasm-gc / JS / native |

依据：[HIDAPI 官方头文件](https://github.com/libusb/hidapi/blob/master/hidapi/hidapi.h)、
[node-hid 官方 API](https://github.com/node-hid/node-hid#complete-async-api)、
[hid-tools 报告与字段实现](https://github.com/bentiss/hid-tools/blob/master/hidtools/hid.py)、
[Microsoft Waratah 功能说明](https://github.com/microsoft/hidtools#waratah)。
hid-tools 的 Python 内部 API 不保证稳定，见 [官方说明](https://github.com/bentiss/hid-tools#hidtools-python-module)。
MoonHID 可与设备通信适配层组合；原生枚举和 Output/Feature 传输属于后续阶段，详见功能范围。

## 安装

在现有 MoonBit 模块目录中执行：

```sh
moon add We1chan/moonhid
```

在使用库的包的 `moon.pkg` 中声明导入，别名与下方 API 示例一致：

```text
import {
  "We1chan/moonhid" @moonhid,
}
```

若只在 blackbox 测试中调用，导入声明后加 `for "test"`。

## 快速运行

安装 [MoonBit 官方工具链](https://www.moonbitlang.com/download/) 后：

```sh
git clone https://github.com/We1chan/moonhid.git
cd moonhid
moon run src/cmd/main
```

程序打印三个设备样例的字段偏移、数字 Usage 和原始整数值。其中鼠标样例
`05 ff 02 fe` 表示按钮 1 和 3 按下，X/Y/滚轮变化分别为 `-1 / 2 / -2`；
手柄样例带 Report ID `7`，两个 16 位轴分别为 `-32768 / 32767`。

## 文件命令行工具

CLI 提供 native 与 Node.js 后端，文件按 UTF-8 十六进制文本读取：

```sh
moon run src/cmd/moonhid --target native -- inspect descriptor.hex
moon run src/cmd/moonhid --target native -- lint descriptor.hex
moon run src/cmd/moonhid --target native -- decode --kind input descriptor.hex report.hex
moon run src/cmd/moonhid --target js -- inspect descriptor.hex
moon run src/cmd/moonhid --target native -- generate keyboard
moon run src/cmd/moonhid --target native -- encode --kind output --id 0 examples/codec/keyboard.hex examples/codec/keyboard-led-values.json
moon run src/cmd/moonhid --target js -- encode --kind feature --id 7 examples/codec/vendor-feature.hex examples/codec/vendor-feature-values.json
```

`inspect` 输出完整描述符 JSON v2；`decode` 输出带 `schema_version: 2` 的
`wire_hex` / `decoded` 组件。报告文件应包含所需的 Report ID 前缀。
方向可以是 input、output、feature；成功退出 0，输入/文件/诊断错误退出 1，参数错误退出 2。
错误写入 stderr，格式为 `code @offset: message`；`inspect` / `decode` 成功时 stdout 只含 JSON。

仓库新增的 `lint` 子命令每条向 stdout 输出一行检查结果，例如
`warning usage_count @18: ...`，没有提示时 stdout 为空。退出 0 表示无 Warning（可以有 Info），
1 表示文件/输入/编译错误，2 表示参数错误，3 表示存在 Warning；详细规则见 [lint 说明](../docs/lint.md)。
`inspect` 的 JSON v2 新增 `lints` 数组，有 Warning 仍成功退出 0。
这些功能从 0.3.0 提供；使用 0.2.0 时需要升级。

仓库 0.4.0 的 `generate` 从 MoonBit 构建器生成 mouse / keyboard / gamepad 描述符，stdout 为十六进制。
`encode` 读取按字段、元素顺序排列的 JSON 数组，例如 `[1, 1, 0, 0, 0]` 编码键盘 LED Output 为 `03`；
超宽字段用 `{"hex": "ff ff ff ff 01"}`。`--id 0` 用于不带 ID 的报告。
成功时 stdout 只含生成的十六进制；错误码沿用 1/2。示例与完整格式见 [codec 文档](../docs/codec.md)。

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

直接打开 [在线检查器](https://we1chan.github.io/moonhid/)。
[Release](https://github.com/We1chan/moonhid/releases/tag/v0.3.0) 提供编译好的离线包：
解压后只需 Node.js 22+，Windows 双击 `start-inspector.cmd`，
其他系统运行 `node scripts/serve-offline.mjs`，不需要 MoonBit 或 Python。

从源码运行：

安装 MoonBit、Node.js 22+ 和 Python 3 后：

```sh
node scripts/build-web.mjs
python3 scripts/serve-web.py
```

打开 <http://127.0.0.1:8765/>。macOS 可直接双击仓库根目录的
[start-inspector.command](../start-inspector.command)，自动构建并打开浏览器；
终端中按 `Ctrl+C` 关闭服务。端口被其他程序占用时，可设置 `MOONHID_PORT=8766`。

界面分为三栏：左侧是描述符编辑器和逐项注释的 Items 列表，中间是报告选择、原始报告输入、
按字节排列的位布局和解码值表，右侧是字段详情与 Collection 树。窄屏时按同一顺序单列排列，
浅色与深色主题跟随系统设置。

点击鼠标、键盘或手柄载入合成样例。粘贴自己的描述符后会自动解析；在报告标签中选择
Input / Output / Feature 与 Report ID，填入完整报告后自动解码，`Ctrl/⌘ + Enter` 立即执行。
每个报告的输入分别保留；键盘切换到 Output 后可点「载入样例报告」，检查 `03` 的 LED 值。
位布局、解码值表、Items 和字段详情相互关联：选择字段会在两个十六进制编辑器中标出对应的
描述符 item 与报告字节，并在解码值表中显示目标字段所在页；当前页已有该字段时保留页码。
点击 Global / Local item 或 Collection 会标出它们在描述符中的字节范围。
十六进制输入错误会在编辑器中标红，并给出字符或字节偏移；首字节 Report ID 与所选报告不一致时，
可以一键切换到对应报告。

左侧中文 lint 面板区分 Warning / Info，可筛选、分页并定位 item 与字段。
编译成功但有 Warning 时仍可解码；未产生提示不等于协议认证。
中栏「发现问题 → 修改 → 验证」案例演示 Hat Null 范围修正和同一报告的解码变化。
固件团队可复制 [完整 CI 示例](../docs/firmware-ci.md)，检查描述符及保存的报告预期值。

页面不加载外部脚本或 CDN，数据只在页面内处理。本地服务只监听 `127.0.0.1`。
解码值表每页最多 200 行，Items 每页最多 500 项，位布局最多展示前 256 个字节，Collection 树最多列出 500 个；
分页表格、报告输入和 JSON 保留完整数据。位布局每行一个字节、左侧为最高位，载荷按 HID 的 LSB 位序解释。
「导出 JSON」保存当前描述符及已成功解码的报告，格式见 [JSON v2](../docs/json-v2.md)。
生成的 `web/moonhid-core.js` 不提交，始终从仓库中的 MoonBit 源码构建。

## WebHID 实时输入

在 Chromium 中使用 HTTPS 或 `http://127.0.0.1` 打开检查器，先粘贴并解析描述符，
再点「连接 HID」选择设备。WebHID 不提供原始描述符，需要按
[读取方法](../docs/real-devices.md#自行读取描述符) 自行获取。
Chrome 会屏蔽键盘和鼠标的受保护 Collection；手柄与厂商自定义 Collection 是否可用由浏览器决定。

页面只接收 Input 报告，非零 `reportId` 补回数据前缀后交给 MoonBit 解码。
每帧显示最新报告，计数包含收到的全部事件；不同 ID 自动切换到对应 Input 布局。
同一报告的刷新保留字段按钮和键盘焦点，可以在接收过程中选择字段和定位错误。
点「断开」或拔出设备会停止监听，之后可继续离线编辑。页面不发送 Output/Feature 报告。

「与浏览器 collections 对照」比较方向/ID/载荷位数，以及 Main 字段的 size、count、flags、
Logical 和 Usage。WebHID 顶层 reports 已包含嵌套集合字段，避免重复计数。
缺少报告可能来自浏览器保护规则或粘贴的描述符不匹配，不应直接视为 MoonHID 解析错误。
WebHID 不暴露完整原始项，String/Designator/Delimiter 等元数据不参与此对照。

[Xbox 蓝牙实测](../docs/xbox-bluetooth.md) 已记录 42 条实际 Input，验证 A 状态、左轴两端和回中，
并重放原始数据。检查器提供独立的「手柄实机验证」入口：浏览器可见字段生成参考布局，
逻辑范围不完整时需明确选择原始位值模式；不会冒充原始设备描述符。
自动测试仍用模拟 HIDDevice 覆盖前缀、DataView 子视图、连接/断开、热拔插和连接中取消；
这些生命周期模拟不能代表已通过对应硬件验收。

## API 示例

以下代码也参与自动测试：

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

生成 LED 描述符，编码报告，再按 Usage 定位并修改字段：

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

主要接口：

| 接口 | 用途 |
| --- | --- |
| `parse_hex` | 严格解析连续或 ASCII 空白分隔的十六进制字节对 |
| `parse_items` | 保留 item 类型、tag、原始数据和字节位置 |
| `serialize_items` | 原始短项/长项序列化，保留宽度与数据，可与分词无损往返 |
| `DescriptorBuilder` | 生成描述符；Usage、范围、集合、ID、三方向、Physical/Unit、Push/Pop；`build()` 校验 |
| `unsigned_value` / `signed_value` | 小端短项数值，完整保留 32 位范围 |
| `field_usage` | 按序查询 Usage；Variable 越界重复最后一项，Array 越界返回 None |
| `compile_descriptor` | 计算 Main 字段、集合树、元数据、报告 ID 与位偏移 |
| `lint_descriptor` | 检查可编译描述符的映射与结构风险；核心 API 见 [lint 说明](../docs/lint.md)，从 0.3.0 提供 |
| `decode_unit` / `effective_physical_range` | 展开单位维度，并应用 HID 物理范围缺省规则 |
| `descriptor_to_json` / `layout_to_json` / `report_to_json` | 导出版本化描述符与布局、解码组件 |
| `lint_to_json` | 导出含级别、item 偏移与可选字段索引的 lint 组件 |
| `report_length` | 查询指定方向和 ID 的完整报告字节长度 |
| `extract_bytes` | 按 LSB 位序提取原始字节，支持非字节对齐 |
| `extract_bits` | 提取跨字节、带符号或无符号的位字段 |
| `insert_bits` / `insert_bytes` | 在副本中写入整数或原始位字段，保留其他位 |
| `decode_report` | 校验长度并返回变量值、数组 Usage 与 Null State 标记 |
| `encode_report` | 根据布局编码 `Integer` / `Raw` 值，校验数量、类型、范围，自动写 ID 与零填充 |
| `read_field` / `write_field` | 按字段和元素索引读写单个值，包含报告长度与归属校验 |
| `find_fields` / `array_selector` | 查询 Variable Usage 的全部字段引用，或把 Array Usage 转为逻辑选择器 |

完整类型签名见 [pkg.generated.mbti](pkg.generated.mbti)。

## 支持范围与边界

- 仓库提供独立的描述符 lint 核心（从 0.3.0 提供）；Warning / Info 不改变编译结果。
  规则包括 `logical_max_sign`、`physical_max_sign`、`null_without_room`、`usage_count`、`missing_usage`、
  `unaligned_report`、`field_outside_application`、`collection_without_usage`、
  `multiple_applications_without_report_id`、`report_id_shared_across_applications`，
  触发条件与级别是契约，见 [规则依据与限制](../docs/lint.md)。JSON v2、bridge、CLI 与中文网页面板均已接入。
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
- 构建器为有状态、可链式调用的对象，第一项参数错误保留至 `build()`。
  调用方显式定义 Report ID、填充与集合结束；当前不自动分配 ID、补齐字节、推断位宽或优化全局状态。
  原始序列化可保存未知项，生成可编译描述符须通过 `build()`。
- String / Designator 索引和区间保存为字段与 Collection 元数据，随后清空本地状态；
  Delimiter 按 Linux 的公共 Usage + 第一个集合规则解码，后续集合保存在 `alternate_usages`。
  嵌套、无开启的关闭和未闭合返回 `delimiter`；索引范围错误返回 `local_range`，
  每类索引最多 1024 段（`local_limit`），优选与备选 Usage 合计最多 1024 段（`usage_limit`）。
  长项仅支持原始分词，布局编译会拒绝；保留字也明确报错；Buffered Bytes 返回 `buffered_bytes`。Physical 范围和 Unit 全局项允许存在，
  解码返回原始整数，不进行物理单位换算。核心保留数字 Usage；页面只补充常见 Usage 名称，
  不是完整 HID Usage Tables 数据库。
- 限制：描述符最多 65536 字节，最多 4096 个 Main 报告字段，整数每值 1..32 位，超过 32 位的 Data Variable 字段按原始字节解码，
  Constant 字段也允许超宽；Data Array 位宽仍限 1..32。
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
└── README.md                # 指向 src/README.mbt.md
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
node scripts/firmware-ci.mjs
moon info
moon fmt --check
```

CI 的 JS 任务也构建浏览器模块，并验证三个样例、LED Output、多 ID、Feature、
Physical/Unit、完整 uint32 和错误路径。CLI 进程回归额外验证三种模板的生成、编码与解码、LED Output 和超宽 Feature。
独立 hid-tools 对照与 headless Chrome DOM 检查也纳入 JS CI，验证真实描述符布局与界面。
四后端还运行固定种子的随机字节、结构化有效描述符与真实描述符突变；
语料、资源边界及解码性质见 [模糊测试验收](../docs/fuzz-validation.md)。
浏览器人工和自动验收记录见
[检查器验收](../docs/inspector-validation.md)。[性能基准](../docs/performance.md) 记录实际来源
描述符与资源上限报告的 bridge/JSON 耗时，每次 CI 保存测量结果。

## 协议与参考

- [USB-IF HID 1.11](https://www.usb.org/document-library/device-class-definition-hid-111)
- [Linux 内核：HID report descriptors](https://docs.kernel.org/hid/hidintro.html)

本项目按公开协议独立实现。仓库内的合成设备样例用于测试声明的支持范围。
采用 Apache-2.0 许可证，见 [LICENSE](../LICENSE)。

代码、测试与文档包含 AI 辅助开发成果。正式参赛前应由参赛者审阅实现，
理解协议与边界，并按比赛规则自行撰写参赛提案。
