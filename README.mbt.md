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

这是正在开发的初始版本，尚未发布到 mooncakes.io。核心库为纯 MoonBit，
已实现十六进制输入、短项/长项分词、布局编译和报告解码。
仓库提供合成的鼠标、键盘和手柄样例，运行时不依赖 USB 权限、真实设备或网络服务。
浏览器查看器、真实设备兼容性验证和正式发布见 [开发路线](ROADMAP.md)。

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
| `compile_descriptor` | 计算 Main 字段、Usage、报告 ID 与位偏移 |
| `report_length` | 查询指定方向和 ID 的完整报告字节长度 |
| `extract_bits` | 提取跨字节、带符号或无符号的位字段 |
| `decode_report` | 校验长度并返回变量值、数组 Usage 与 Null State 标记 |

完整类型签名见 [pkg.generated.mbti](pkg.generated.mbti)。

## 支持范围与边界

- 支持 Input / Output / Feature、Usage / Usage 范围 / 32 位扩展 Usage、
  Logical 范围、Report Size / Count / ID、Global Push / Pop 与 Collection 配对检查。
- 变量字段按声明顺序对应 Usage，数量不足时重复最后一个 Usage。
  数组值按 `value - logical_min` 索引 Usage 列表；未映射的值保留原值。
- 保留填充字段的布局，解码输出省略 Constant 字段；保留超出逻辑范围的值，
  通过 `in_logical_range` 和 `is_null` 区分异常值与声明的 Null State。
- 字段位偏移从报告载荷的第 0 位计算，不含 Report ID 字节；解码输入必须包含
  描述符要求的 ID 前缀，并且长度必须精确匹配，不能带额外传输层前缀或尾部字节。
- 长项仅支持原始分词，布局编译会拒绝；保留字、Delimiter、Designator、String
  本地项及 Buffered Bytes 目前也会明确报错。Physical 范围和 Unit 全局项允许存在，
  当前仅返回原始整数，不计算物理单位。尚不输出 Collection 层级树或 Usage 名称。
- 限制：描述符最多 65536 字节，最多 4096 个 Main 报告字段，每值 1..32 位，
  每字段最多 1024 个值，每报告最多 65536 位，Usage 列表最多 1024 项，
  Collection 与 Global 栈深度最多 64。Global Push/Pop 要求平衡。
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
moon info
moon fmt --check
```

## 协议与参考

- [USB-IF HID 1.11](https://www.usb.org/document-library/device-class-definition-hid-111)
- [Linux 内核：HID report descriptors](https://docs.kernel.org/hid/hidintro.html)

本项目按公开协议独立实现。仓库内的合成设备样例用于测试声明的支持范围。
采用 Apache-2.0 许可证，见 [LICENSE](LICENSE)。

代码、测试与文档包含 AI 辅助开发成果。正式参赛前应由参赛者审阅实现，
理解协议与边界，并按比赛规则自行撰写参赛提案。
