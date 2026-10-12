# 0.4.0 编解码与生成验收

此记录保留 0.4.0 发布前的源码验收结果，发布与独立安装结果另见 [发布说明](release-0.4.0.md)。

## 最新工具链兼容修复

2026-10-12 的 CI 固定版本四后端全部通过，但 `latest-toolchain (js)` 在 MoonBit
`0.10.15+943464bfa` 下因 43 处 `.to_json()` 弃用调用失败。转换统一改为 `Json(value)`，
保留 `number64` 数字编码和 JSON v2 的既有格式。

本地使用原固定工具链验证四后端，每后端 101 项测试、native/JS CLI 与浏览器回归通过；
另使用 CI 同版本的 `moon 0.1.20261012`、`moonc v0.10.15+943464bfa` 验证 JS 无警告检查、
101 项测试、浏览器 bridge 与教学案例通过。公共接口文件没有变化。

## 第二轮：Usage 级接口、物理量换算与新模板

日期：2026-10-12。执行环境为 Windows 11 原生（native 验收对应 MSVC 构建的 Windows 可执行文件），
工具链固定为 `moon 0.1.20260920`、`moonc v0.10.14+7d59c7ec9`，Node.js 24.14.0，
外部对照为 hid-tools 0.12，Python 3.14.3，headless Chrome 为本机 Google Chrome。

| 验收 | 结果 |
| --- | --- |
| `moon check --target <wasm/wasm-gc/js/native> --deny-warn` | 四后端无警告通过 |
| 四后端 build / test / `cmd/main` | 每后端 101 项测试通过（新增 Usage 级、物理量、模板与 lint 为空测试，README 新示例，模糊性质） |
| `moon fmt --check`、`moon info`、`moon info --target native` | 格式通过；接口变化仅为新增函数与 `ReportInfo` |
| `node scripts/test-cli.mjs` | native / JS：五个命令、五种模板、位置与 Usage 两种值文件、错误码、Unicode/空格路径通过 |
| `node scripts/test-web.mjs`、`test-webhid.mjs`、`test-usability.mjs` | 既有 bridge、WebHID 模拟、Null 教学案例与 Xbox 42 帧重放通过 |
| `node scripts/firmware-ci.mjs`（js、native） | 固件 lint 与 Null 回归通过 |
| `node scripts/package-inspector.mjs`、`test-offline.mjs` | 离线包生成与 Node-only 启动通过 |
| `node scripts/test-inspector.mjs` | headless Chrome DOM 检查通过 |
| `python scripts/compare-hid-tools.py` | A–G 七份真实描述符布局对照无差异 |
| `python scripts/compare-codec-hid-tools.py` | 五个模板与 fixture 逐字节相同；7 组位置值、6 组 Usage 形式经 hid-tools 独立填入/读回一致 |

Usage 形式的外部对照结果：

| 模板/方向 | ID | Usage 编辑 | wire |
| --- | --- | --- | --- |
| keyboard Input | 0 | 按下 Left Shift、A、C | `02 00 04 06 00 00 00 00` |
| keyboard Output | 0 | 点亮 Num Lock、Caps Lock | `03` |
| mouse Input | 0 | 按钮 1、3；X -1，Y 2，滚轮 -2 | `05 ff 02 fe` |
| gamepad Input | 7 | 按钮 1、12；X -32768，Y 32767 | `07 01 08 00 80 ff 7f` |
| consumer Input | 0 | Play/Pause | `cd 00` |
| vendor Output | 0 | 空闲报告 | 64 个 `00` |

`consumer` 与 `vendor` 模板另与 TinyUSB `TUD_HID_REPORT_DESC_CONSUMER()`、
`TUD_HID_REPORT_DESC_GENERIC_INOUT(64)` 的展开结果逐字节比较。

本轮修正两处既有问题：构建器对 Minimum ≥ 0、Maximum 为 128..255 等值生成 `25 ff` 这类单字节编码，
会触发本项目 lint `logical_max_sign`，现改为读法一致的最短宽度；`test-cli.mjs` 在 Windows native 上
因 CRLF 换行失败，现统一按 LF 比较输出。

## 第一轮：编码、生成与字段读写

日期：2026-10-12。执行环境为 Windows 主机上的 WSL Ubuntu；native 验收对应 Linux 可执行文件。
工具链同上，Node.js 22.20.0，hid-tools 0.12，Python 3.12.3。

| 验收 | 结果 |
| --- | --- |
| `moon check --target all --deny-warn` | 四后端无警告通过 |
| 四后端 build / test / `cmd/main` | wasm、wasm-gc、JS、native，每后端 91 项测试通过，示例编解码一致 |
| `node scripts/test-cli.mjs` | native / JS 的五个命令、Unicode/空格路径、退出码、三模板往返、LED Output、Raw Feature 通过 |
| `node scripts/test-web.mjs` | 既有 JS bridge、JSON v2、uint32、lint 与错误路径通过 |
| `node scripts/test-webhid.mjs` | 模拟设备、ID、DataView、连接/断开/取消等生命周期通过 |
| `node scripts/test-usability.mjs` | Null 教学案例与 Xbox 蓝牙 42 帧重放通过 |
| `node scripts/firmware-ci.mjs` | 固件 lint 与 Null 回归通过 |
| `python scripts/compare-hid-tools.py` | A–G 七份真实描述符的方向/ID、长度与字段对照无差异 |
| `python scripts/compare-codec-hid-tools.py` | 三份生成描述符与独立 fixture 相同，四种报告经 hid-tools 独立填入/读取一致 |

编码单元测试另覆盖三方向多 ID、signed/unsigned32 边界、非字节对齐、Null、
字段与元素归属、Raw 类型/长度/尾位、最大报告、严格范围和异常原值重放。
原始 bit 写入测试检查每个未选中的相邻位，模糊语料继续执行 Item 无损往返与解码→编码→解码性质。

## 尚未覆盖

页面未新增编码界面。未进行新硬件 Output/Feature 实测，Usage 级接口与新模板也未经实机验收。
新增功能边界及后续设备接入计划见 [功能范围](features.md)。
