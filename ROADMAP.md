# MoonHID 开发路线

项目名称：**MoonHID：基于 MoonBit 的 HID 报告描述符解析与报告解码工具库**。

这是仓库的开发计划。功能状态以代码、测试和可运行示例为准。

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

## 下一阶段：协议覆盖与验证

- 中文 lint、item/字段定位、Null 教学案例、固件回归示例、在线与预编译离线检查器已完成。
- 后续增加报告编码与往返性质测试。
- String/Designator 与 Delimiter 备选 Usage 已保留；长项和 Buffered Bytes 继续明确拒绝。
- 增加非字节对齐手柄、带多个 ID 的复合设备、Feature 报告和异常描述符样例。
- 七份本机真实描述符已公开、通过结构回归和 hid-tools 0.12 独立布局对照。
- 已有确定性模糊测试与资源上限回归；已加入七份真实描述符及资源上限的可复现性能基准。

## 发布与参赛验收

- 参赛者审阅代码并能解释状态机、位序、逻辑范围、数组 Usage 和支持边界。
- 模块 `We1chan/moonhid` 的 0.2.0 发布与安装验收已完成；后续发布沿用已记录的流程。
- 稳定 CI 已固定工具链，另设最新兼容检查；交付入口和版本结果见 0.3.0 发布说明。
- 根据比赛最新版规则由参赛者自行撰写提案；报名与最终验收分开确认。

## 当前范围之外

核心库聚焦报告描述符与原始报告的解释，网页另提供可选 WebHID Input 接收。
直接 USB/Bluetooth 传输、操作系统驱动、固件烧录与设备控制暂不纳入范围。
