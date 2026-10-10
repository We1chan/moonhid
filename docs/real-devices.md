# 真实 HID 描述符回归

这七份描述符由参赛者在本机 macOS 上于 2026-10-01 使用
`ioreg -r -c IOHIDDevice -l -w0` 读取，并通过本地交接文件提供。
回归样例只保留 `ReportDescriptor` 的字节，不包含序列号、设备路径、按键记录或实时报告。
原始十六进制见 [real_devices_test.mbt](../src/real_devices_test.mbt)。

这里验证的是保存的描述符能否编译，以及报告结构是否符合断言；
它不能证明设备通信、实时输入或所有同型号设备都已兼容。

## 初始结果

基线提交：`3d03182`。偏移从描述符第 0 字节开始。

| 样例 | 设备 / Collection Usage | 字节 | 编译结果 | 后续待修复语义 |
| --- | --- | ---: | --- | --- |
| A | als，`0xff00:0x04` | 20 | 成功：Input ID 0，256 位，1 个字段 | — |
| B | Apple Internal Keyboard / Trackpad，Mouse | 195 | `report_size`，偏移 56 | 16384 位 Constant Feature；Report Count 1751 |
| C | Apple Internal Keyboard / Trackpad，`0xff00:0x5f` | 36 | `report_size`，偏移 28 | 16384 位 Constant Feature |
| D | Apple Internal Keyboard，Keyboard | 189 | `report_size`，偏移 181 | 16384 位 Constant Feature |
| E | Headset，Consumer | 29 | 成功：Input ID 0，8 位，2 个字段 | — |
| F | BTM，`0xff00:0x48` | 50 | `item_size`，偏移 33 | 零长度 Logical Maximum；16024 位 Input 和 1144 位 Feature |
| G | VK M5，Keyboard | 243 | `usage_range`，偏移 102 | 32768 个 System Control Usage |

失败样例先断言当前诊断码和偏移。修复时逐项改为成功断言，
同时检查报告方向、ID、载荷位数、字段数量与关键字段的 size / count / flags。

## 自行读取描述符

macOS：

```sh
ioreg -r -c IOHIDDevice -l -w0
```

在目标设备的条目内查找 `ReportDescriptor`，复制尖括号内的十六进制到检查器。
一台复合设备可能对应多个 HID 条目。公开样例时只复制描述符，
不要附带整份 `ioreg` 输出里的序列号和其他个人设备信息。

Linux：

```sh
od -An -v -tx1 /sys/class/hidraw/hidraw0/device/report_descriptor
```

根据自己的设备将 `hidraw0` 换成正确条目。读取权限由系统决定；
无需向设备发送报告或切换协议。

## 兼容性修复进度

零长度数据已按 0 解释，超宽 Variable 字段使用原始字节，Constant 字段保留布局。
A–G 七份描述符现已全部编译成功，并断言完整报告列表和字段 size / count / flags。
Report Count 现由每报告 65536 位预算约束；G 的 32768 个 System Control Usage
保留为一个区间，编译时不展开。

| 样例 | 当前报告（方向 / ID / 载荷位数） | 字段数 |
| --- | --- | ---: |
| A | Input / 0 / 256 | 1 |
| B | Input / 2 / 56；Feature / 2 / 32768；Input / 63 / 128；Input / 68 / 14008；Input / 91 / 768 | 15 |
| C | Input / 224 / 32；Feature / 224 / 32768 | 2 |
| D | Input / 1 / 72；Output / 1 / 8；Input / 82 / 8；Feature / 9 / 24；Input / 63 / 512；Feature / 63 / 32768 | 19 |
| E | Input / 0 / 8 | 2 |
| F | Feature / 1 / 16；Input / 2 / 16024；Feature / 2 / 1144 | 4 |
| G | Input / 1 / 64；Output / 1 / 8；Input / 2 / 16；Input / 3 / 16；Input / 7 / 120；Input / 5 / 56；Input / 6 / 520；Output / 6 / 520 | 15 |

## lint 结果

2026-10-02 使用新增的 `lint_descriptor` 核心 API 检查同一份 A–G 字节，
共得到 4 条 Warning、0 条 Info；三份合成 fixture 没有 Warning。
规则、级别与规范依据见 [lint 说明](lint.md)，这里只解释这些保存样例的具体结果。
所有提示的 code / level / offset / field_index 已在 `real_devices_test.mbt` 固定。
offset 是描述符字节偏移，field_index 是编译布局中的零起始字段索引。

| 样例 | 级别 / code | offset / field_index | 判断与可能影响 |
| --- | --- | --- | --- |
| A | Warning / `missing_usage` | 17 / 0 | `0xff00:0x04` 被前面的 Collection 消耗，Input 没有自己的 Usage。MoonHID 仍保留 32 字节原值，但没有 Usage 映射；Linux 的通用字段注册可能将其当作填充。专用驱动如何读取不在本次验证范围内。 |
| B | Warning / `usage_count` | 114 / 6 | Input ID 68 的厂商 Array 只有一个 `0xff00:0x0c` Usage，逻辑域却有 256 个选择值；Count 1751 表示元素槽数。按当前映射只有值 0 有对应 Usage，其余原值仍保留。可能是以单 Usage 标注原始数据块的设计，不能仅据此认定描述符有错。 |
| C–F | 无提示 | — | 在现有规则范围内未发现提示；不代表实机通信或所有 HID 约束均已通过。 |
| G | Warning / `usage_count` | 236 / 13；240 / 14 | Input 与 Output ID 6 各有 65 个字节槽，一个 `0xff55:0x02` Usage 对应 256 个逻辑选择值。和 B 类似，可能是厂商原始协议的标签。实际应用应按该设备协议解释其余字节，不能推断厂商写错。 |

本轮未修改真实描述符，也未读取、发送实时报告。lint 不改变先前的编译、解码或独立布局对照结果。

## 独立工具对照

2026-10-02 在本机运行外部 [hid-tools](https://gitlab.freedesktop.org/libevdev/hid-tools)
0.12（Python 3.13.15）。工具按其 GPL 许可作为独立依赖安装和运行，
仓库没有复制其实现。复验命令：

```sh
node scripts/build-web.mjs
uv run --with hid-tools==0.12 python scripts/compare-hid-tools.py
```

没有 uv 时，可以在自己的 Python 虚拟环境安装 `hid-tools==0.12`，
再运行同一脚本。JS CI 也执行对照，结果见 [记录 JSON](hid-tools-comparison.json)。

| 样例 | 报告数 | MoonHID Main 字段数 | hid-tools 字段数 | 规范化后差异 |
| --- | ---: | ---: | ---: | --- |
| A | 1 | 1 | 1 | 无 |
| B | 5 | 15 | 64 | 无 |
| C | 2 | 2 | 5 | 无 |
| D | 6 | 19 | 93 | 无 |
| E | 1 | 2 | 4 | 无 |
| F | 3 | 4 | 4 | 无 |
| G | 8 | 15 | 150 | 无 |

共比较 26 个报告和 58 个 Main 字段。逐报告比较 kind / ID / 总载荷位数；
逐字段比较偏移、覆盖位数、size / count、flags、Logical 范围和数字 Usage。
字段数量不同是表示方式差异：MoonHID 保留每个 Main item，hid-tools 将 Variable / Constant
元素拆成多项，也会把未声明 Usage 的填充合并。对照脚本按原 Main 字段边界规范化这些项；
hid-tools 的 report bitsize/start 包含 ID 时减去 8 位，未编号 ID -1 对应 MoonHID 的 0。
Data Array 的 size / count 与完整 Usage 序列直接比较。

当前仅对以上七份保存的描述符建立一致性证据；没有实际读写设备，
也不把两个解析器的一致结果当作完整 HID 协议认证。
