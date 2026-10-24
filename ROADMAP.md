# MoonHID 开发路线

项目名称：**MoonHID：基于 MoonBit 的通用 HID 报告编解码与描述符工具库**。

这是仓库的开发计划。功能状态以代码、测试和可运行示例为准。
完整范围、成熟库对比与分层验收见 [功能范围](docs/features.md) 和 [README](src/README.mbt.md)。

## 已实现的起点

- 十六进制与二进制输入、诊断位置、短项与长项分词。
- 常用 Main / Global / Local 项、零长度数据、区间 Usage、Report ID 与 Global Push/Pop。
- Input / Output / Feature 独立布局、跨字节字段、整数解码、数组 Usage、Null State。
- 鼠标、键盘和手柄合成样例，键盘 LED 输出报告测试。
- 四后端 CI：检查、构建、测试和运行示例；native/Node JS 文件 CLI 支持 inspect/decode。
- Collection 层级树和字段所属集合，保留 Physical 范围与 Unit 元数据。
- JSON schema v2：超过 32 位的字段保留原始字节；描述符、原始 items、报告布局、物理/单位信息与解码值，保留数字 Usage。
- 交互式浏览器页面：粘贴十六进制、展开 item、检查字段位布局、选择 ID 与报告方向。
- 字符/字节错误定位、字段来源、常见 Usage 名称、长表分页和 JSON 下载。
- 可选 WebHID Input 实时模式与 collections 对照，已有模拟适配器/DOM 回归，已有 Xbox 蓝牙实际 Input 验收与 42 帧重放；其他硬件仍需实测。
- 浏览器 JS 模块由 MoonBit 源码构建，Node 桥接测试纳入 CI，提供 macOS 双击启动入口。
- 固定种子的随机字节、结构化有效描述符与七份真实描述符突变，四后端检查资源边界和解码性质。
- 0.3.0 已发布到 mooncakes.io，在线/离线入口可用，并完成独立项目的四后端安装验收。
- 仓库新增描述符 lint 核心、JSON v2 `lints` 和 native/Node CLI `lint`，有规则依据及正反例；归入 0.3.0 发布。
- 仓库 0.4.0 新增三方向报告编码、Integer/Raw、范围与 Null 校验、跨字节写入和零填充。
- 新增字段 read/write、Variable Usage 查询、Array 选择器、低层位/字节插入。
- 新增描述符构建器、Item 序列化、五种设备模板与 CLI `encode` / `generate`；媒体键与厂商数据模板与 TinyUSB 宏展开逐字节相同，构建器的 Maximum 编码不再触发 `logical_max_sign`。
- 新增参照 Windows HID 解析库（`hidpi.h`）的 Usage 级接口：报告目录与初始化、按键/按钮置位与列出、按 Usage 读写数值、物理量换算；CLI `encode` 支持按 Usage 描述的值文件，并经 hid-tools 独立对照。
- 既有模糊语料加入 Item 无损往返与报告往返性质，约定见 [codec](docs/codec.md)。
- 0.4.0 已发布到 mooncakes.io，独立项目四后端各 6/6 安装验收通过，见 [发布说明](docs/release-0.4.0.md)。
- 0.5.0 增加 Buffered Bytes；0.5.2 完成 Mooncakes 文档入口修复与独立安装验收，见 [发布说明](docs/release-0.5.2.md)。
- 0.6.0 已发布；干净克隆完整验收 23 项通过，四后端各 123/123；注册表独立安装各 14/14，71 份文件逐字节一致。公开链接、离线包与 Pages 的实际结果见 [交付记录](docs/release-0.6.0.md#2026-10-23-实际交付验收)。
- 0.6.1 更新 AI 协作说明，修复 Windows 默认换行下的验收测试并新增 Windows 一键验收 CI，见 [发布说明](docs/release-0.6.1.md)。
- 0.6.0 网页支持 Input / Output / Feature 报告初始化、按字段/元素编辑与完整 HEX 导出，复用 MoonBit 核心的 ID、Null、Array、Raw 和 Buffered Bytes 语义；见 [网页报告编辑](docs/browser-editor.md)。

## 下一阶段：协议覆盖与验证

- 中文 lint、item/字段定位、Null 教学案例、固件回归示例、在线与预编译离线检查器已完成。
- 报告编码、往返性质和网页字段编辑/编码导出已实现；0.6.0 新增结构化声明 v1 与 build/declare，五个模板和七份真实描述符/codec 数据逐字节回放，见 [声明格式](docs/declaration.md)；[批量帧重放](docs/replay.md) 提供行号、逐帧错误与 Usage 期望，已核对 Xbox 42 帧和合成固件案例。
- 纯 MoonBit `transport` 帧转换已通过四后端合成验证，Windows HIDAPI 链接/初始化探针通过；[记录与范围](docs/hidapi-validation.md) 区分软件帧、虚拟环境与实机证据。原生收发适配器及可选网页 Output/Feature 发送保留为后续工作。
- String/Designator 与 Delimiter 备选 Usage 已保留；Buffered Bytes 已支持，布局编译继续明确拒绝长项。
- 增加非字节对齐手柄、带多个 ID 的复合设备、Feature 报告和异常描述符样例。
- 七份本机真实描述符已公开、通过结构回归和 hid-tools 0.12 独立布局对照。
- 已有确定性模糊测试与资源上限回归；已加入七份真实描述符及资源上限的可复现性能基准。
- 后续补完整 Usage 名称数据包、单位制转换与可选自动填充/ID，逐项增加独立语义回归。

## 设备传输适配阶段

- 定义独立设备适配包：设备信息、枚举、打开/关闭、Input 订阅、Output 发送、Feature 读写。
- 浏览器在已有 Input 基础上增加 Output/Feature，验证与核心 wire 的 ID/payload 分离。
- 原生后端通过 HIDAPI FFI 接入，验证无 ID 的额外 0 前缀、断开处理和平台错误传播。
- 至少完成键盘 LED Output 和厂商 Feature 实机验收，公开设备与平台后再计入支持范围。

## 发布与参赛验收

- 参赛者审阅代码并能解释状态机、位序、逻辑范围、数组 Usage 和支持边界。
- 模块 `We1chan/moonhid` 的 0.2.0 发布与安装验收已完成；后续发布沿用已记录的流程。
- 稳定 CI 已固定工具链，另设最新兼容检查；交付入口和版本结果见 [0.6.1 发布说明](docs/release-0.6.1.md)。
- 报名与最终验收按比赛最新版规则分开提交。

## 当前范围之外

核心覆盖描述符生成与解释、报告编解码和字段访问，网页提供可选 WebHID Input。
原生通信和浏览器 Output/Feature 处于规划阶段；驱动开发、烧录和直接实现 USB/Bluetooth 协议不纳入范围。
