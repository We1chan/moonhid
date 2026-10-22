# 开发过程与 AI 协作说明

本说明区分仓库可验证的开发证据与参赛者当前说明的过程事实。
它不是比赛验收提交正文。技术设计见 [核心设计说明](design.md)，当前支持范围见 [功能范围](features.md)。

## 参赛者负责的部分

2026-10-22，参赛者将本轮实现、测试、文档与交付工作交由 Codex 继续推进。
本轮代码实现、接口草稿、验证命令执行、文档整理，以及按验收计划建立 Issue/PR、检查 CI 后合并，均由 Codex 自动化完成。
仓库账号上的提交和合并记录不表示这些操作由参赛者手工逐项执行。

参赛者在本轮事实确认环节明确表示目前不了解实现，尚未声明已经审阅并掌握核心设计。
因此，“参赛者能独立解释状态机、位序、Array/Null、物理量、编码和支持边界”尚未获得验证。
[设计说明](design.md) 提供可核对的材料；参赛者仍需亲自阅读、复现和讲解，才可将本人理解作为验收证据。

仓库 [Xbox 记录](xbox-bluetooth.md) 记载：参赛者在 Windows Chrome 操作蓝牙手柄并采集实际 Input。
这份证据没有原始设备描述符，不能推导出全部硬件或传输兼容性。

## AI 参与的部分

当前聊天中的 Codex 工作包括实现草稿、测试、文档和复核，并通过 `codex/*` 分支 PR 留下记录。
例如 [网页字段编辑 #40](https://github.com/We1chan/moonhid/pull/40)、
[README 跨平台地址 #38](https://github.com/We1chan/moonhid/pull/38)、
[标准证据与文档入口复核 #37](https://github.com/We1chan/moonhid/pull/37)。
分支名、提交者账号或 AI 生成的文字本身不能证明参赛者已经审阅、理解或确认全部内容。

本轮可验证的 AI 工具为 Codex。此前是否还使用 Claude Code、ChatGPT 或其他工具没有得到完整信息，
本说明仅记录有证据的部分，不从仓库中的 `CLAUDE.md` 文件名推断完整工具清单。

本项目没有将 AI 输出或 CI 全绿作为协议认证结论。已发布的事实和仍在规划的能力分别记录，
实机操作与验收提交材料由参赛者本人完成。

## 质量控制与证据分级

| 证据 | 回答的问题 | 记录 |
| --- | --- | --- |
| 四后端检查/构建/测试 | 相同核心语义能否在 wasm、wasm-gc、JS、native 运行 | [CI](https://github.com/We1chan/moonhid/actions/workflows/ci.yml) |
| 固定报告字节与拒绝案例 | 约定的编码/解码与错误是否符合独立预期 | [报告案例](report-cases.md) |
| hid-tools 0.12 独立对照 | 布局、字段值和生成的报告是否与独立实现一致 | [真实描述符](real-devices.md)、[编解码验收](codec-validation.md) |
| 固定种子模糊测试 | 随机/突变输入是否崩溃，资源上限与往返性质是否保持 | [模糊测试](fuzz-validation.md) |
| 注册表独立安装 | 公开包是否能从注册表下载并在仓库外使用 | [0.6.0 安装记录](registry-0.6.0-validation.json)，四后端各 14/14，71 份文件逐字节匹配发布提交 |
| 线上真实链接检查 | GitHub、Mooncakes 和交付入口实际是否可访问 | [独立排查](review-audit-2026-10-20.md) |
| 浏览器模拟适配器与 DOM | ID/载荷分离、生命周期、界面操作和导出是否正确 | [检查器验收](inspector-validation.md) |
| 真实设备采集与重放 | 已记录的手柄操作是否对应实际收到的 Input 位值 | [Xbox 蓝牙记录](xbox-bluetooth.md) |

合成样例、模拟设备、原始真实描述符与实机 Input 分开记载；它们均不能代替未完成的真实 Output/Feature 收发验收。
本机验证和已公开发布也分别记录，未发布的源码能力不能当成注册表版本的功能。

## 发现并纠正的问题

| 问题 | 复核与纠正 |
| --- | --- |
| Xbox 轴 Logical Max 被错误缩窄 | 浏览器参考描述符把轴上限 -1 写成单字节 ff，实际中位值被标为越界；采集器拒绝不完整范围，并显式区分按位宽查看模式。[记录](xbox-bluetooth.md) |
| README 符号链接导致 404 | 改用生成的普通 README 并检查实际链接。[PR #36](https://github.com/We1chan/moonhid/pull/36)、[排查记录](review-audit-2026-10-20.md) |
| 33 位 Raw 混入标准案例 | 独立审计后将 Raw 标成宽松扩展，新增普通 Feature 标准案例并独立对照。[PR #37](https://github.com/We1chan/moonhid/pull/37)、[兼容说明](hid-compatibility.md) |
| 0.5.1 文档验收未通过 | 包内和模块 README 的基址不同，发布后仍检出 27 个错误相对链接；0.5.2 改成明确跨页地址并重新下载安装核验。[0.5.1 历史记录](release-0.5.1.md)、[0.5.2](release-0.5.2.md)、[PR #38](https://github.com/We1chan/moonhid/pull/38) |

这些纠错记录保留失败事实，不用“本地测试通过”覆盖线上交付失败，也不把历史失败版本重新表述成有效修复。
