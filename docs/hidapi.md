# HIDAPI 接入的可行性与范围

0.6.0 源码提供纯 MoonBit `We1chan/moonhid/transport` 帧转换包和可复现的链接/UHID 探针。
原生设备的枚举、打开、订阅、Output/Feature 收发 API 和 `moonhid-hid` CLI 仍在规划中。
本轮没有参赛者确认可供操作的 LED/Feature 实机；计划要求的实机操作仍由参赛者完成。
在拿到设备和完整收发证据前，发布范围保留为协议工具和帧转换。

## 帧转换

```text
to_hidapi(layout, kind, wire) -> Result[Bytes, Diagnostic]
from_hidapi(layout, kind, buffer) -> Result[Bytes, Diagnostic]
to_webhid(layout, kind, wire) -> Result[WebFrame, Diagnostic]
from_webhid(layout, kind, WebFrame {report_id, payload}) -> Result[Bytes, Diagnostic]
```

先编译描述符，再将同一 Layout 和方向传入这些函数；它们复用核心解码器检查 ID 和精确长度。
Raw、Null、异常原值以及 Constant 位均按原始字节保留，不重新编码，也不写设备。

| 接口 | 不带 Report ID | 带 Report ID |
| --- | --- | --- |
| 核心 wire | 仅 payload | ID + payload |
| HIDAPI Input 读取 | 仅 payload | ID + payload |
| HIDAPI Output/Feature 缓冲区 | `00` + payload | ID + payload |
| WebHID | `(0, payload)` | `(ID, payload)` |

例如键盘 LED 核心 wire `02` 转为 HIDAPI Output 缓冲区 `00 02`，
WebHID 帧为 `(0, 02)`。有 ID 的 Feature `07 a5` 在 HIDAPI 中仍是 `07 a5`，
在 WebHID 中则是 `(7, a5)`。从 HIDAPI 还原无 ID 的 Output/Feature 时，
缺少或错误的零前缀为 `transport_id`；非法 WebHID ID 同样返回此码、offset 0。
未知 ID、错误方向和长度保留核心 `unknown_report` / `report_length` 诊断。

四个后端的帧测试覆盖三方向、有/无 ID、前缀、长度、未知报告与 Constant 位保留。
这些是合成字节测试，设备 API 由后续独立适配层提供。

## 复现 native 链接验证

[MoonBit native 配置](https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html#native-backend-link-options)
支持 `native-stub`、`stub-cc-flags` 与 `cc-link-flags`。
`node scripts/probe-hidapi.mjs` 在 `_build/hidapi-link-probe` 创建一次性模块，
用 C 桩实际链接系统库、调用 `hid_init` / `hid_exit`，并要求能链接
HIDAPI 0.14 起的 `hid_get_report_descriptor` 符号。探针不枚举或打开设备。
生成结果为 `_build/hidapi-feasibility.json`。

Linux：

```sh
sudo apt-get update
sudo apt-get install -y libhidapi-dev
node scripts/probe-hidapi.mjs
```

macOS（当前未实测）：

```sh
brew install hidapi
HIDAPI_INCLUDE_DIR="$(brew --prefix hidapi)/include/hidapi" HIDAPI_LINK_FLAGS="-L$(brew --prefix hidapi)/lib -lhidapi" node scripts/probe-hidapi.mjs
```

Windows：从 [HIDAPI 官方发布](https://github.com/libusb/hidapi/releases/tag/hidapi-0.15.0)
下载 `hidapi-win.zip`，使用与本机 native 编译器架构一致的 `.lib` 和 `.dll`。
MoonBit 使用 MSVC 工具链；MSYS/MinGW 的导入库不能代替该 `.lib`。

```powershell
$env:HIDAPI_INCLUDE_DIR = 'D:\tools\hidapi\include'
$env:HIDAPI_LINK_FLAGS = 'D:\tools\hidapi\x64\hidapi.lib'
$env:PATH = "D:\tools\hidapi\x64;$env:PATH"
node scripts/probe-hidapi.mjs
```

成功输出 `PASS` 和实际 HIDAPI 版本。缺少头文件、链接符号或运行库会退出 1，
不能用“编译过了”替代初始化成功或设备收发成功。HIDAPI 是外部依赖，未复制其实现源码。

## Linux UHID 枚举验证

```sh
sudo modprobe uhid
python3 -m venv _build/hidapi-venv
_build/hidapi-venv/bin/pip install hid-tools==0.12
sudo _build/hidapi-venv/bin/python scripts/probe-hidapi-uhid.py --require
```

脚本使用 hid-tools 创建一台合成厂商 Feature 虚拟设备，仅用 HIDAPI 枚举该虚拟 VID/PID，
再与该对象拥有的 sysfs hidraw 节点匹配。只记录匹配数量和库版本，不打印序列号。
结果写到 `_build/hidapi-uhid-feasibility.json`。
该脚本不打开设备、不收发报告；不能作为完整 HIDAPI 适配器的验收。
hid-tools 是外部 GPL 测试工具，其源码没有并入 MoonHID 库。

CI 的 native 任务安装系统 HIDAPI 并运行两项探针，上传 `hidapi-feasibility` artifact。
缺少 `/dev/uhid` 时记录 `SKIP`，不计为通过；本地需要将 SKIP 作为失败时使用 `--require`。
若宿主内核把 UHID 编译为模块且没有安装，可安装对应 `linux-modules-extra-$(uname -r)` 后重试。

## 后续原生适配的验收门槛

设备 API 需要独立 native 包、自动关闭的句柄、带平台/操作的错误、有限超时和无序列号日志。
先在虚拟设备验证描述符、Input、LED Output、GET/SET_FEATURE，再由参赛者进行实机操作。
Linux 应按设备 VID/PID 设置 udev 权限；macOS 键盘操作需要按系统提示授予输入监控权限；
Windows 键盘/鼠标集合可能由系统独占。不要为通过测试而扩大真实设备的写入范围。
具体平台限制以 [HIDAPI 文档](https://github.com/libusb/hidapi) 和
[WebHID 规范](https://hid.spec.whatwg.org/) 为准；WebHID 受保护集合包括键盘，网页 LED 例子是离线编码演示。

实际环境与证据分级见 [验证记录](hidapi-validation.md)。
