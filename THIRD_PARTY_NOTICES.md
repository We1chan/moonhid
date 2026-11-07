# 第三方材料声明

MoonHID 的代码、文档和本项目编写的样例按 [Apache-2.0](LICENSE) 发布，项目版权与归属声明见 [NOTICE](NOTICE)。
本文件登记 Git 仓库中来自第三方的材料，写明来源、版本或采集日期、版权归属和许可。
由仓库构建或发布的产物同样适用本声明，包括 Mooncakes 包 `We1chan/moonhid`、CLI 可执行文件、
`web/moonhid-core.js`、GitHub Pages 检查器和 Release 附带的离线检查器压缩包。
0.6.1 及更早版本的发布包没有附带本文件和 `NOTICE`，其中的 TinyUSB 派生内容同样适用第 1 节的版权与许可声明。

## 1. TinyUSB HID 描述符宏（MIT）

| 项目 | 内容 |
| --- | --- |
| 上游 | [hathach/tinyusb](https://github.com/hathach/tinyusb) |
| 版本 | [0.21.0](https://github.com/hathach/tinyusb/releases/tag/0.21.0)，提交 `dae3f9a366bfcddbf9dcf1b48d7500286a849539` |
| 来源文件 | [`src/class/hid/hid_device.h`](https://github.com/hathach/tinyusb/blob/dae3f9a366bfcddbf9dcf1b48d7500286a849539/src/class/hid/hid_device.h)（Git blob `32b572973824f038c54b63c8a1b124cc82876935`）中的 `TUD_HID_REPORT_DESC_CONSUMER(...)` 与 `TUD_HID_REPORT_DESC_GENERIC_INOUT(report_size, ...)`；展开时使用同一提交的 [`src/class/hid/hid.h`](https://github.com/hathach/tinyusb/blob/dae3f9a366bfcddbf9dcf1b48d7500286a849539/src/class/hid/hid.h)（Git blob `0883d95ac6add187a95b072c8fcf8c2ad99f9fd0`）中的条目宏 |
| 版权 | 两个来源文件的文件头：`Copyright (c) 2019 Ha Thach (tinyusb.org)`；上游 `LICENSE`：`Copyright (c) 2012-2026, hathach (tinyusb.org)` |
| 许可 | MIT License，全文见本节末尾 |

仓库不包含 TinyUSB 的 C 源码。MoonHID 用 MoonBit `DescriptorBuilder` 按这两个宏的条目顺序重新编写媒体键和厂商数据模板，
生成的描述符与宏展开结果逐字节相同；测试和示例数据保存展开后的十六进制字节，用于逐字节比对。
下表中的文件属于 TinyUSB 派生材料，按 MIT 许可随附上述版权声明和许可全文：

| 文件 | 与 TinyUSB 的关系 |
| --- | --- |
| `src/examples/templates.mbt` | `consumer_descriptor()` 对应不带 Report ID 的 `TUD_HID_REPORT_DESC_CONSUMER()`；`vendor_descriptor(report_bytes~)` 对应不带 Report ID 的 `TUD_HID_REPORT_DESC_GENERIC_INOUT(report_bytes)` |
| `src/examples/templates_test.mbt` | 两个宏在不带 Report ID、`report_size` 为 64 时的展开字节 |
| `examples/codec/consumer.hex`、`examples/codec/vendor.hex` | 同一组展开字节 |
| `examples/declarations/consumer.json`、`examples/declarations/vendor.json` | 用声明 JSON 表达的同一条目序列 |
| `src/cmd/moonhid/main.mbt` | CLI `generate consumer` 与 `generate vendor` 输出上述两个模板 |
| `src/access_test.mbt` | 两段以 `06 00 ff 09 01 a1 01 09 02` 开头的厂商描述符沿用同一结构，Report Count 和后续条目已改动 |

`examples/codec/` 中的 `consumer-values.json`、`consumer-report.hex`、`vendor-values.json` 等报告值由本项目编写，不来自 TinyUSB。

核对记录：2026-11-07 取得上述提交的两个头文件，用 C11 编译器展开
`TUD_HID_REPORT_DESC_CONSUMER()` 与 `TUD_HID_REPORT_DESC_GENERIC_INOUT(64)` 并输出字节，
结果与 `examples/codec/consumer.hex`、`examples/codec/vendor.hex` 逐字节相同：

```text
05 0c 09 01 a1 01 15 00 26 ff 03 19 00 2a ff 03 95 01 75 10 81 00 c0
06 00 ff 09 01 a1 01 09 02 15 00 26 ff 00 75 08 95 40 81 02 09 03 15 00 26 ff 00 75 08 95 40 91 02 c0
```

0.4.0（2026-10-12）引入这两个模板时，文档只链接了 TinyUSB master 分支，没有记录版本；本声明将比对基准固定为 0.21.0。

TinyUSB 许可全文（上游 [`LICENSE`](https://github.com/hathach/tinyusb/blob/dae3f9a366bfcddbf9dcf1b48d7500286a849539/LICENSE)，Git blob `0680c2f055bf770cad5a44321db41ed0f8fb0f36`）：

```text
The MIT License (MIT)

Copyright (c) 2012-2026, hathach (tinyusb.org)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

`hid_device.h` 与 `hid.h` 文件头使用同一 MIT 许可条款，版权行为 `Copyright (c) 2019 Ha Thach (tinyusb.org)`。

## 2. 实机采集的描述符与报告

以下数据由参赛者从自己的设备读取，不是开源许可材料。仓库只保留描述符字节和采集时的报告载荷，
不含序列号、设备路径或其他个人设备信息。

| 材料 | 来源 | 所在文件 |
| --- | --- | --- |
| 七份 HID 报告描述符 A–G | 2026-10-01 在 macOS 上用 `ioreg -r -c IOHIDDevice -l -w0` 读取；设备为 als 传感器、Apple Internal Keyboard / Trackpad、Headset、BTM 和 VK M5 | `src/real_devices_test.mbt`；其他测试和脚本按函数名或正则读取同一数据；说明见 [真实设备回归](docs/real-devices.md) |
| Xbox 蓝牙手柄 42 条 Input 报告 | 2026-10-07 在 Windows Chrome 中经 WebHID 采集，VID/PID `045e:0b13` | `examples/device-cases/xbox-bluetooth*`、`src/xbox_bluetooth_test.mbt`；说明见 [Xbox 蓝牙手柄实测](docs/xbox-bluetooth.md) |

描述符字节由各设备固件提供，是主机解析报告所需的接口数据，收录它们只为互操作测试。
MoonHID 不主张对这些字节拥有权利，Apache-2.0 授权也不涉及设备厂商可能享有的权利。
`examples/device-cases/xbox-bluetooth-descriptor.hex` 是本项目根据观测到的位布局编写的参考描述符，不是设备原始描述符。
Apple、Xbox 等名称是各自权利人的商标，这里只用来标明数据来源。

## 3. 本项目编写的样例

下列材料由本项目编写，按 Apache-2.0 发布：

- `src/examples/fixtures.mbt` 中的鼠标、键盘、手柄样例，按 HID 1.11 常见设备结构编写，没有从其他项目复制。
- `examples/codec/`、`examples/declarations/`、`examples/firmware-ci/` 中除第 1 节所列文件以外的描述符、报告和值文件。
- `web/` 中的页面、脚本、样式和 `favicon.svg`。

## 4. 规范与参考资料

- USB-IF《Device Class Definition for HID 1.11》和《HID Usage Tables》：解析与编解码按规范独立实现，仓库不包含规范文本。
  `web/app.js` 和文档中少量 Usage 名称（如 `Left Shift`、`Caps Lock`）沿用 Usage Tables 的命名，用作标识。
- README 的功能对比表引用 Windows `hidpi.h`、hid-tools、TinyUSB、usbd-hid、Microsoft Waratah、HIDAPI 和 node-hid 的公开接口名称与文档链接，不包含它们的代码。
- Linux 内核 HID 文档只作为链接引用。

## 5. 构建和测试时使用、不随仓库分发的依赖

| 依赖 | 版本 | 许可 | 用途 |
| --- | --- | --- | --- |
| [moonbitlang/x](https://github.com/moonbitlang/x) | 0.5.5 | Apache-2.0 | `moon.mod` 声明的依赖，构建时由 Mooncakes 下载 |
| MoonBit 工具链 | `toolchain.json` 固定 0.10.18+6c83a7f62 | 以官方发布条款为准 | 编译、测试与格式检查 |
| [hid-tools](https://gitlab.freedesktop.org/libevdev/hid-tools) | 0.12 | GPL-2.0（以上游 `COPYING` 为准） | `scripts/compare-hid-tools.py` 与 `scripts/compare-codec-hid-tools.py` 作为独立进程调用它做对照；仓库不复制其代码，`docs/hid-tools-comparison.json` 是对照运行记录 |
| [HIDAPI](https://github.com/libusb/hidapi) | 运行环境中安装的版本 | 上游 `LICENSE`：BSD、GPLv3 与原始 HIDAPI 许可三选一 | `scripts/probe-hidapi.mjs` 在临时目录中链接系统库，只检查链接与版本，不打开设备 |
| Node.js 22+、Python 3、Google Chrome | 运行环境中安装的版本 | 各自的许可 | 运行脚本、对照与浏览器测试 |

## 维护规则

新增来自第三方的代码、数据、宏展开或实机采集记录时，在本文件登记上游、版本或采集日期、版权归属与许可，
并在相关源码注释中指向本文件。`node scripts/check-notices.mjs` 检查第 1 节列出的文件、版权行和许可全文是否齐全。
