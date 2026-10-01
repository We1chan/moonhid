# 真实 HID 描述符回归

这七份描述符由参赛者在本机 macOS 上于 2026-10-01 使用
`ioreg -r -c IOHIDDevice -l -w0` 读取，并通过本地交接文件提供。
回归样例只保留 `ReportDescriptor` 的字节，不包含序列号、设备路径、按键记录或实时报告。
原始十六进制见 [real_devices_test.mbt](../real_devices_test.mbt)。

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

## 独立工具对照

待协议兼容性修复后，使用外部独立解析器逐个比较报告和字段。
目前尚未执行独立工具对照，也没有捕获真实输入报告。
