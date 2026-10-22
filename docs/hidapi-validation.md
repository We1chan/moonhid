# HIDAPI 可行性验证记录

2026-10-23，按十月验收计划 T6 执行链接、帧转换与虚拟环境可行性验证。
本页记录与实际设备收发分开；原生 HIDAPI 适配器仍为规划状态。

| 层级 | 环境与命令 | 实际结果 |
| --- | --- | --- |
| 合成帧 | Windows x64，固定 MoonBit；`moon test src/transport --target all` | 四后端各 4/4；键盘 Input/LED、Feature、ID/长度正反例通过 |
| 完整核心回归 | `moon check --target all --deny-warn`、`moon test --target all` | 四后端各 123/123，检查无警告 |
| native 链接 | Windows x64 / MSVC，官方 HIDAPI 0.15.0 x64；`node scripts/probe-hidapi.mjs` | PASS；实际链接 0.14+ 描述符符号，`hid_init` / `hid_exit` 成功，运行版本 0.15.0 |
| Linux 链接/UHID | CI native 任务运行同一链接探针与 `scripts/probe-hidapi-uhid.py` | 以 PR 的 artifact 为准；没有实际结果前不计为通过 |
| macOS | Homebrew HIDAPI 链接配置已提供 | 未运行 |
| 实机 LED/Feature | 尚未取得参赛者确认的设备与操作记录 | 未运行；不替代原有 Xbox Input 采集证据 |

Windows 链接探针只执行初始化和版本查询，没有枚举或打开真实设备，没有发送 Output/Feature。
临时头文件、`.lib`、`.dll` 存于工作区外的 `.review-tools`，未打包进 MoonHID。
命令、版本与退出码保存在 `_build/hidapi-feasibility.json`。

当前结论：native 链接可行；是否能在 GitHub Ubuntu 创建并枚举 UHID，以 CI 实际观测为准。
原生收发和可选网页 Output/Feature 发送暂不纳入本次发布支持范围。
后续实现入口、权限说明和需要补齐的完整收发测试见 [接入说明](hidapi.md)。
