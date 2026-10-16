# Buffered Bytes 源码修订验收

日期：2026-10-16。环境：macOS arm64，`moon 0.1.20260920`、
`moonc v0.10.14+7d59c7ec9`、Node.js 24.19.0、hid-tools 0.12、本机 headless Google Chrome。
本记录对应 0.4.0 之后的 Buffered Bytes 源码修订，不改变 0.4.0 的发布与安装记录。

## 执行结果

| 验收 | 结果 |
| --- | --- |
| `moon check --target all --deny-warn` | 四后端无警告通过 |
| `moon build --target all` | wasm、wasm-gc、JS、native 构建通过 |
| `moon test --target all` | 每后端 112 项全部通过，含四段 README 可执行示例 |
| `moon info`、`moon info --target native`、`moon fmt --check` | 公共 API 新增 `BufferedValue` 和 `DecodedReport.buffered_values`；格式通过 |
| `node scripts/build-web.mjs`、`test-web.mjs` | JSON v2、三方向原始缓冲区与既有 bridge 回归通过 |
| `node scripts/test-cli.mjs` | native / JS 均通过；直接消费仓库中的三方向 Buffered Bytes 案例，位置和 Usage 两种值文件及错误码通过 |
| `node scripts/test-webhid.mjs`、`test-usability.mjs` | WebHID 生命周期、三方向 Buffered Bytes 参考描述符（含 raw 模式）、既有教学案例与 Xbox 42 帧重放通过 |
| `node scripts/test-inspector.mjs` | 1440、1100、390 宽度通过；513 字节缓冲区只占一行，完整导出，不产生整数范围或 Null 判定，错误后清空旧数据 |
| `node scripts/firmware-ci.mjs`、`node scripts/firmware-ci.mjs native` | JS / native 固件 lint 与 Null 回归通过 |
| `node scripts/package-inspector.mjs`、`test-offline.mjs` | 离线包生成与 Node-only 启动回归通过 |
| `uv run --with hid-tools==0.12 python scripts/compare-hid-tools.py` | 既有七份真实描述符、26 个报告布局无差异 |
| `uv run --with hid-tools==0.12 python scripts/compare-codec-hid-tools.py` | 既有 7 组位置编解码、6 组 Usage 编辑独立对照通过 |

native CLI 没有 canonical Wasm interface 的提示符合该 CLI 的后端配置；核心生成接口的差异仅为上述新增类型和字段。
公开结构体的手工构造者需新增 `buffered_values`；既有函数签名和整数/超宽字段含义不变。

## Buffered Bytes 的具体证据

`src/buffered_test.mbt` 有九组确定结果测试：三方向、无 ID 与多 ID、32 位以内也必须 Raw、
Size 不等于 8 的整段流、数值与缓冲区混排、保留相邻 Constant 位、长度/类型/数量/ID 错误、
非字节对齐和保留 Main 标志、最大 8192 字节载荷、Usage 访问与数值语义隔离。
预期 wire 为手工指定字节，不仅检查本库编码与解码的往返。

固定种子 `b00f1234` 生成 128 个布局、384 个混合报告，覆盖标量、Buffered Bytes 和超宽 Variable。
既有随机字节与真实描述符变异也继续执行；新成功编译的缓冲区检查完整长度、内容往返及字段读取。

[兼容说明](hid-compatibility.md) 中六条 CLI 命令已直接执行。
Input、Output、Feature 均编码为 `05 4d 4f 4f 4e`，
解码分别得到字段 0、1、2 的 `buffered_values`；整数与超宽数组均为空。
浏览器 1440 和 390 宽度的截图已目视核对，缓冲区按整段显示，长值在表格内预览，JSON 保留全部 513 字节。

Buffered Bytes 证据来自标准语义与离线合成案例；既有 hid-tools 对照覆盖原有字段和设备布局，
未被计作 Buffered Bytes 的独立编解码或实机证据。本次没有新增硬件采集或 Output/Feature 实机发送。
