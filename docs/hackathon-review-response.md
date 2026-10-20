# MoonHID 初审反馈补充说明

针对“仍然没有明确完整报告编解码的标准兼容目标说明，也没有附带案例；仓库里文档访问 404”，补充如下。

## 标准目标与完整报告

MoonHID 的兼容目标为 **USB-IF HID 1.11 Report Descriptor 驱动的离线 Report Protocol 编解码**，
依据 §6.2.2 和 §8.1–8.3。对一个方向与 Report ID，编码器处理全部 Data 字段并生成含 ID 和填充的完整报告；
解码器按描述符提取该报告全部 Data 值、Usage、范围/Null 状态和原始字节。
覆盖 Input、Output、Feature、Report ID、Variable、Array、Constant、Null State 与 Buffered Bytes。

[标准兼容目标](hid-compatibility.md) 逐项列出标准条款、实际处理、源码测试与限制，明确区分
原始标志保留、数值/Usage 解释和物理量换算。资源上限、超宽 Array、Delimiter、长项、
USB 传输和 Boot Protocol 的边界一并列明。Buffered Bytes 已在 0.5.0 提供，0.4.0 不含此支持。

## 可复现案例与证据

[完整报告案例](report-cases.md) 附描述符、值文件、固定 wire、解码预期和命令，覆盖：

- 键盘 Input 的修饰键与六键 Array，LED Output 的位字段与填充。
- 鼠标负位移、带 ID 的 signed16 手柄、16 位媒体键 Array。
- 带 ID、填充及跨字节的 33 位 Raw Feature，Hat Null State。
- Buffered Bytes 的 Input / Output / Feature 三方向。

仓库根目录运行 `node scripts/test-compatibility.mjs`，或加 `native` 选择 native CLI，
每个后端检查 10 个正例和 7 个错误案例。解码使用预先保存的报告，独立核对全部值，
不会仅以本库编解码往返作为标准兼容证据。清单见
[compatibility-cases.json](../examples/codec/compatibility-cases.json)，两后端均加入 CI。

既有 [四后端与 Buffered Bytes 验收](buffered-bytes-validation.md)、
[hid-tools 对照](codec-validation.md)、[真实描述符](real-devices.md) 与 [Xbox 实机 Input](xbox-bluetooth.md)
分别提供对应范围的补充证据。新增案例为离线合成数据，不作为 Output/Feature 实机发送或完整设备认证证明。

## 文档 404 的原因与修复

仓库根目录的 `README.md` 原为指向 `src/README.mbt.md` 的符号链接。
GitHub 在仓库首页展示内容时，按首页所在路径解析 `../docs/...`，使兼容说明等链接成为
`/We1chan/moonhid/blob/docs/...`，遗漏 `main` 并返回 404。文件存在也无法从首页访问。

修复将首页改为普通 Markdown 文件，从可执行 README 生成并把本地链接转换到根目录路径。
`node scripts/sync-readme.mjs --check` 检查两份内容同步和本地文档目标存在，已加入 CI。
可直接复核以下入口：

- [标准兼容目标](https://github.com/We1chan/moonhid/blob/main/docs/hid-compatibility.md)
- [完整报告案例](https://github.com/We1chan/moonhid/blob/main/docs/report-cases.md)
- [在线检查器](https://we1chan.github.io/moonhid/)
- [0.5.0 发布与安装验收](https://github.com/We1chan/moonhid/blob/main/docs/release-0.5.0.md)

可通过 `moon add We1chan/moonhid@0.5.0` 安装核心库。本次补充围绕说明、案例与文档导航，
未改变核心编解码 API；从源码复核新增案例时请使用包含本次修复的提交。
