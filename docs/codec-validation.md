# 0.4.0 编解码与生成验收

日期：2026-10-12。此记录针对仓库源码，0.4.0 尚未发布到 mooncakes.io，也未更新在线检查器。
执行环境为 Windows 主机上的 WSL Ubuntu；native 验收对应 Linux 可执行文件。
工具链固定为 `moon 0.1.20260920`、`moonc v0.10.14+7d59c7ec9`，Node.js 22.20.0，
外部对照为 hid-tools 0.12，Python 3.12.3。

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

外部编码对照结果：

| 设备/方向 | ID | wire |
| --- | --- | --- |
| mouse Input | 0 | `05 ff 02 fe` |
| keyboard Input | 0 | `02 00 04 06 00 00 00 00` |
| keyboard Output | 0 | `03` |
| gamepad Input | 7 | `07 01 08 00 80 ff 7f` |

编码单元测试另覆盖三方向多 ID、signed/unsigned32 边界、非字节对齐、Null、
字段与元素归属、Raw 类型/长度/尾位、最大报告、严格范围和异常原值重放。
原始 bit 写入测试检查每个未选中的相邻位，模糊语料继续执行 Item 无损往返与解码→编码→解码性质。

本机没有运行 headless Chrome DOM 检查，既有 CI 保留该任务；页面未新增编码界面。
未进行新硬件 Output/Feature 实测，也未执行 0.4.0 发布与发布后安装验收。
新增功能边界及后续设备接入计划见 [功能范围](features.md)。
