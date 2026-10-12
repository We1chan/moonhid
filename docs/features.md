# MoonHID 功能范围与验收

MoonHID 为 MoonBit 提供可组合的通用 HID 报告工具库。
使用链路为：声明生成描述符 → 编译布局 → 查询/读写字段 → 编码或解码报告 → 交给设备传输层。
核心负责报告协议，CLI 和浏览器负责检查与复现，设备连接由独立适配层接入。
状态以代码和测试为准；已发布版本为 0.3.0，仓库 0.4.0 新增能力尚未发布。

## 当前核心能力

| 模块 | 已实现范围 | 公开入口 / 验收 |
| --- | --- | --- |
| 二进制输入 | 严格 hex、诊断、短项/长项分词、小端数值 | `parse_hex`、`parse_items`；截断、零长度、uint32 |
| 原始描述符编辑 | Item 序列化，保留宽度与未知数据 | `serialize_items`；原始 bytes 无损往返 |
| 描述符创作 | Usage/范围/扩展 Usage、集合、三方向、ID、Physical/Unit、Push/Pop | `DescriptorBuilder`；生成后编译；三模板与独立字节比较 |
| 布局与元数据 | 每方向/ID 独立偏移、Constant、Array、集合树、String/Designator、Delimiter | `compile_descriptor`；七份真实描述符与 hid-tools 对照 |
| 报告解码 | Variable/Array、Null、有符号/无符号、跨字节、超宽原始值 | `decode_report`；真实输入、样例与模糊报告 |
| 报告编码 | 三方向、多 ID、整数/原始值、类型/范围/数量校验、零填充 | `encode_report`；独立 wire 与解码往返 |
| 字段定位 | Variable 数字 Usage 全部引用、Array Usage 逻辑选择器 | `find_fields`、`array_selector`；重复 Usage 与非零 Minimum |
| 字段读写 | 单元素读取、在副本中改整数/原始值、保留相邻位 | `read_field`、`write_field`；ID、Constant、跨字节与尾位 |
| 原始位操作 | LSB 位提取/插入，有符号整数与原始字节 | `extract_bits` / `insert_bits`、`extract_bytes` / `insert_bytes` |
| 协议检查 | 十项 lint、稳定诊断、版本化 JSON | `lint_descriptor`、JSON v2；正反例与 CLI 退出码 |
| 多后端 | 核心 wasm / wasm-gc / JS / native，CLI native / Node.js | 四后端 check/build/test 与可执行文档 |

模板用于独立字节验收；厂商 Feature 示例展示超宽原始字段。报告类型和 Usage 由描述符驱动，
布局不限制为这几种设备。成熟库功能表与官方依据见 [README](../src/README.mbt.md#与成熟-hid-库的功能对比)，
接口与前缀约定见 [编解码文档](codec.md)。

## 工具与设备接入

| 层 | 当前状态 | 后续验收目标 |
| --- | --- | --- |
| 文件 CLI | inspect / lint / decode / encode / generate，Unicode 路径、机器可读输出、退出码 | 结构化描述符声明文件、批量帧重放 |
| 浏览器检查器 | 描述符/布局/解码/JSON 导出、WebHID Input、collections 对照 | 字段编辑、编码导出、Output/Feature 适配 |
| 设备传输适配 | 浏览器 Input 与 Xbox 蓝牙实测，核心离线 Bytes | 独立设备信息、枚举、打开/关闭、Input 订阅、Output 发送、Feature 读写；验证 ID、长度、断开和错误 |
| 原生 HID 接入 | 规划阶段 | native HIDAPI FFI；至少键盘 LED 和厂商 Feature 实机验收，记录平台、权限和驱动限制 |
| Usage/单位语义 | 数字 Usage、常见名称、Unit/Physical 元数据 | 完整 Usage 名称数据包、精度与范围明确的物理量换算 |
| 描述符便捷性 | 显式尺寸、ID、填充、集合结束，最小短项整数宽度 | 可选自动填充、自动 ID、冗余全局项优化；语义布局独立对照 |

后续能力未计入当前支持。每项有可运行示例、正反例测试及对应后端验收后再宣称完成。
核心保持纯 MoonBit，平台传输适配使用独立包。

## 明确边界

- 核心解析 HID Report Descriptor，不解析 USB 设备/配置描述符或独立 Physical Descriptor。
- 编译长项、保留项、Buffered Bytes 明确报错；原始分词/序列化仍保留它们。
- 整数每元素 1..32 位；更宽 Variable 用 Raw；Data Array 限 1..32 位。
  不做物理量换算，不包含完整 Usage 名称数据库。
- 报告最多 65536 位，描述符最多 65536 字节，4096 字段/集合、64 层栈，其他限额见 README。
- 当前不操作驱动、切换 Boot Protocol、枚举原生设备或发送实际 Output/Feature；
  这些传输功能处于明确规划阶段，核心可提供所需编码数据。
- 既有真实描述符与 Xbox Input 验收不代表新生成/编码功能已通过更多硬件验收。

## 0.4.0 验收清单

1. 新公共接口出现在 `pkg.generated.mbti`，可从独立导入包使用。
2. 四后端无警告检查、构建、测试，README 示例参与测试。
3. 编码有独立 wire 预期，字段修改检查相邻位；固定语料增加往返性质。
4. native / Node.js CLI 真进程执行生成→编码→解码、LED Output / Raw Feature。
5. 原有 browser bridge、WebHID 模拟和真实布局回归通过，边界与发布状态同步记录。
6. 发布后在独立目录按版本安装验收并更新发布说明；这一步尚未执行。
