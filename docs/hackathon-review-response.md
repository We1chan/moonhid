# MoonHID 初审反馈补充说明

针对“申报排除了 HID 1.11 已定义的 Buffered Bytes 语义”，原实现直接拒绝 Main item bit 8，
与报告级编解码的兼容目标不一致。本次源码修订已补上该语义，并收紧原有范围表述。

兼容目标为 **HID 1.11 Report Descriptor 驱动的离线 Report Protocol 编解码**，覆盖
Input、Output、Feature、Report ID、Variable、Array、Constant、Null State 和 Buffered Bytes。
标准条款、逐项范围、资源上限与传输边界见 [HID 1.11 兼容目标](hid-compatibility.md)。

依据 [HID 1.11 §6.2.2.5 的 bit 8](https://www.usb.org/sites/default/files/documents/hid1_11.pdf#page=41)，
Buffered Bytes 是内容由应用解释的固定字节流。本次实现保留整段字节，检查字节对齐和固定长度，
编码使用一个 `Raw(Bytes)`，解码输出独立的 `buffered_values`，不套用整数范围、Array 或物理量解释。

可复现案例包括应用数据 Input、命令载荷 Output、配置载荷 Feature：
[描述符](../examples/codec/buffered-bytes.hex) 的三个方向均使用 ID 5、Size 8、Count 4、flags 0x102。
输入 [Raw 值](../examples/codec/buffered-bytes-values.json) `4d 4f 4f 4e`，编码得到
`05 4d 4f 4f 4e`，解码分别得到字段 0、1、2 的四字节流。执行命令与预期 JSON 已附在兼容目标中。

[验收记录](buffered-bytes-validation.md) 覆盖四后端、混合数值与字节流、多 ID、长度与对齐错误、
native/JS CLI、JSON 和浏览器展示。样例为离线合成协议数据；Buffered Bytes 的实机验证单独列为后续工作。
本次修订已随 [0.5.0](release-0.5.0.md) 提供，可通过 `moon add We1chan/moonhid@0.5.0` 安装复核。
0.4.0 不含此修订；兼容目标、案例与源码测试可用于补充申报。
