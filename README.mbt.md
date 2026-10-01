# MoonHID

面向 MoonBit 的 HID 报告描述符解析、字段布局计算与离线报告解码工具库。

HID 描述符告诉程序一段设备数据中的哪些位表示按键、鼠标位移或手柄摇杆。
MoonHID 的目标是将这些二进制定义转换为可检查、可复用的数据结构，帮助设备工具、
嵌入式调试程序和浏览器分析器解释报告。

## 预期使用场景

1. 自制键盘：检查按键数组、修饰键和 LED 输出报告的布局。
2. 鼠标与手柄：解释按钮、相对位移、摇杆轴和带 Report ID 的报告。
3. 通用设备工具：在 CI 或浏览器中检查保存的描述符与报告样例，复现解析问题。

## 首版范围

项目正在初始化。首版按以下顺序实现：十六进制输入、HID item 解析、布局编译、
报告解码、样例与自动测试。浏览器查看器和更广泛的设备兼容性检查安排在后续阶段。

核心解析库将保持纯 MoonBit，离线样例不依赖 USB 权限、真实设备或网络服务。

## 开发

安装 [MoonBit 官方工具链](https://www.moonbitlang.com/download/) 后，在项目目录运行：

```sh
moon check
moon test
moon info
moon fmt
```

## 协议与参考

- [USB-IF HID 1.11](https://www.usb.org/document-library/device-class-definition-hid-111)
- [Linux 内核：HID report descriptors](https://docs.kernel.org/hid/hidintro.html)

本项目按公开协议独立实现。仓库内的合成设备样例用于测试声明的支持范围。
采用 Apache-2.0 许可证，见 [LICENSE](LICENSE)。
