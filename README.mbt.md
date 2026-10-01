# MoonHID

[![CI](https://github.com/We1chan/moonhid/actions/workflows/ci.yml/badge.svg)](https://github.com/We1chan/moonhid/actions/workflows/ci.yml)

面向 MoonBit 的 HID 报告描述符解析、字段布局计算与离线报告解码工具库。

HID 描述符告诉程序一段设备数据中的哪些位表示按键、鼠标位移或手柄摇杆。
MoonHID 的目标是将这些二进制定义转换为可检查、可复用的数据结构，帮助设备工具、
嵌入式调试程序和浏览器分析器解释报告。

## 预期使用场景

1. 自制键盘：检查按键数组、修饰键和 LED 输出报告的布局。
2. 鼠标与手柄：解释按钮、相对位移、摇杆轴和带 Report ID 的报告。
3. 通用设备工具：在 CI 或浏览器中检查保存的描述符与报告样例，复现解析问题。

## 当前状态

0.2.0 的源码与 JSON v2 已准备，尚未发布到 mooncakes.io。发布步骤见
[0.2.0 发布说明](docs/release-0.2.0.md)。核心库为纯 MoonBit，
已实现十六进制输入、短项/长项分词、布局编译、Collection 层级、Physical/Unit 元数据和报告解码。
仓库提供合成的鼠标、键盘和手柄样例，以及 [七份真实设备描述符回归](docs/real-devices.md)，运行时不依赖 USB 权限、真实设备或网络服务。
浏览器检查器直接运行 MoonBit 编译的 JS 模块，提供字段布局、解码值与版本化 JSON 导出。
真实设备兼容性验证和正式发布见 [开发路线](ROADMAP.md)。

## 快速运行

安装 [MoonBit 官方工具链](https://www.moonbitlang.com/download/) 后：

```sh
git clone https://github.com/We1chan/moonhid.git
cd moonhid
moon run cmd/main
```

程序打印三个设备样例的字段偏移、数字 Usage 和原始整数值。其中鼠标样例
`05 ff 02 fe` 表示按钮 1 和 3 按下，X/Y/滚轮变化分别为 `-1 / 2 / -2`；
手柄样例带 Report ID `7`，两个 16 位轴分别为 `-32768 / 32767`。

## 浏览器检查器

安装 MoonBit、Node.js 22+ 和 Python 3 后：

```sh
node scripts/build-web.mjs
python3 scripts/serve-web.py
```

打开 <http://127.0.0.1:8765/>。macOS 可直接双击仓库根目录的
[start-inspector.command](start-inspector.command)，自动构建并打开浏览器；
终端中按 `Ctrl+C` 关闭服务。端口被其他程序占用时，可设置 `MOONHID_PORT=8766`。

界面分为三栏：左侧是描述符编辑器和逐项注释的 Items 列表，中间是报告选择、原始报告输入、
按字节排列的位布局和解码值表，右侧是字段详情与 Collection 树。窄屏时按同一顺序单列排列，
浅色与深色主题跟随系统设置。

点击鼠标、键盘或手柄载入合成样例。粘贴自己的描述符后会自动解析；在报告标签中选择
Input / Output / Feature 与 Report ID，填入完整报告后自动解码，`Ctrl/⌘ + Enter` 立即执行。
每个报告的输入分别保留；键盘切换到 Output 后可点「载入样例报告」，检查 `03` 的 LED 值。
位布局、解码值表、Items 和字段详情相互关联：选择字段会在两个十六进制编辑器中标出对应的
描述符 item 与报告字节；点击 Global / Local item 或 Collection 会标出它们在描述符中的字节范围。
十六进制输入错误会在编辑器中标红，并给出字符或字节偏移；首字节 Report ID 与所选报告不一致时，
可以一键切换到对应报告。

页面不加载外部脚本或 CDN，数据只在页面内处理。服务只监听 `127.0.0.1`。
解码值表每页最多 200 行，Items 每页最多 500 项，位布局最多展示前 256 个字节，Collection 树最多列出 500 个；
分页表格、报告输入和 JSON 保留完整数据。位布局每行一个字节、左侧为最高位，载荷按 HID 的 LSB 位序解释。
「导出 JSON」保存当前描述符及已成功解码的报告，格式见 [JSON v2](docs/json-v2.md)。
生成的 `web/moonhid-core.js` 不提交，始终从仓库中的 MoonBit 源码构建。

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

主要接口：

| 接口 | 用途 |
| --- | --- |
| `parse_hex` | 严格解析连续或 ASCII 空白分隔的十六进制字节对 |
| `parse_items` | 保留 item 类型、tag、原始数据和字节位置 |
| `unsigned_value` / `signed_value` | 小端短项数值，完整保留 32 位范围 |
| `field_usage` | 按序查询 Usage；Variable 越界重复最后一项，Array 越界返回 None |
| `compile_descriptor` | 计算 Main 字段、集合树、元数据、报告 ID 与位偏移 |
| `decode_unit` / `effective_physical_range` | 展开单位维度，并应用 HID 物理范围缺省规则 |
| `descriptor_to_json` / `layout_to_json` / `report_to_json` | 导出版本化描述符与布局、解码组件 |
| `report_length` | 查询指定方向和 ID 的完整报告字节长度 |
| `extract_bytes` | 按 LSB 位序提取原始字节，支持非字节对齐 |
| `extract_bits` | 提取跨字节、带符号或无符号的位字段 |
| `decode_report` | 校验长度并返回变量值、数组 Usage 与 Null State 标记 |

完整类型签名见 [pkg.generated.mbti](pkg.generated.mbti)。

## 支持范围与边界

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
- 当前没有设备读写、驱动安装或 Boot Protocol 切换功能；合成样例测试不能代表
  已兼容所有 HID 设备。

错误通过 `Result[..., Diagnostic]` 返回。二进制输入的 `offset` 是字节偏移，
十六进制文本的 `offset` 是 UTF-16 索引。`parse_hex` 不接受 `0x` 前缀、逗号或
字节对内的空白，`05 01`、`0501` 均可。

## 开发

本机验证工具链：`moon 0.1.20260920`、`moonc v0.10.14+7d59c7ec9`。
CI 使用官方最新工具链并在日志记录完整版本，验证四种后端：

```sh
moon check --target all --deny-warn
moon build
moon test
moon test --target native
moon test --target js # 需要 Node.js
node scripts/build-web.mjs
node scripts/test-web.mjs
moon info
moon fmt --check
```

CI 的 JS 任务也构建浏览器模块，并验证三个样例、LED Output、多 ID、Feature、
Physical/Unit、完整 uint32 和错误路径。独立 hid-tools 对照与 headless Chrome DOM 检查也纳入 JS CI，验证真实描述符布局与界面。
浏览器人工和自动验收记录见
[检查器验收](docs/inspector-validation.md)。

## 协议与参考

- [USB-IF HID 1.11](https://www.usb.org/document-library/device-class-definition-hid-111)
- [Linux 内核：HID report descriptors](https://docs.kernel.org/hid/hidintro.html)

本项目按公开协议独立实现。仓库内的合成设备样例用于测试声明的支持范围。
采用 Apache-2.0 许可证，见 [LICENSE](LICENSE)。

代码、测试与文档包含 AI 辅助开发成果。正式参赛前应由参赛者审阅实现，
理解协议与边界，并按比赛规则自行撰写参赛提案。
