# 示例数据

本目录保存 CLI、固件 CI 和回归测试使用的描述符、报告与值文件。各文件的来源与许可如下，
完整声明见 [第三方材料声明](../THIRD_PARTY_NOTICES.md)。

| 目录 / 文件 | 来源 | 许可 |
| --- | --- | --- |
| `codec/consumer.hex`、`codec/vendor.hex` | TinyUSB 0.21.0 `TUD_HID_REPORT_DESC_CONSUMER()`、`TUD_HID_REPORT_DESC_GENERIC_INOUT(64)` 的展开字节；Copyright (c) 2019 Ha Thach (tinyusb.org) | MIT，见 [第三方材料声明](../THIRD_PARTY_NOTICES.md#1-tinyusb-hid-描述符宏mit) |
| `declarations/consumer.json`、`declarations/vendor.json` | 用声明 JSON 表达上述两个 TinyUSB 宏的条目序列 | MIT，同上 |
| `codec/`、`declarations/` 中的其他文件 | 本项目编写 | Apache-2.0 |
| `firmware-ci/` | 本项目编写的固件 CI 示例 | Apache-2.0 |
| `device-cases/xbox-bluetooth-frames.txt`、`device-cases/xbox-bluetooth.json` 中的报告 | 参赛者 2026-10-07 经 WebHID 从自己的 Xbox 蓝牙手柄采集，见 [实测说明](../docs/xbox-bluetooth.md) | 实机数据，说明见 [第三方材料声明](../THIRD_PARTY_NOTICES.md#2-实机采集的描述符与报告) |
| `device-cases/xbox-bluetooth-descriptor.hex`、`device-cases/xbox-bluetooth-expected.jsonl` | 本项目根据观测到的位布局编写的参考描述符和预期值，不是设备原始描述符 | Apache-2.0 |
