# MoonHID 0.6.0

0.6.0 将描述符创作、报告编辑和批量回归连接起来。核心继续使用纯 MoonBit，
支持 wasm / wasm-gc / JS / native；文件 CLI 使用 JS/native，展示 JSON 保持 v2。

## 本次新增

- [网页报告编辑](browser-editor.md)：初始化三方向报告，按字段/元素编辑，导出完整 wire HEX；
  Windows / Chrome 线上操作已验证 LED `00 → 02 → 03`、`e0 → e2` 和非法值保持原报告。
- [四场景入口](scenarios.md)：键盘、鼠标/手柄、媒体键/厂商配置、固件回归，
  一条 `moon run src/cmd/scenarios` 输出实际 API 结果与完整固定预期。
- [结构化声明 v1](declaration.md)：`descriptor_from_declaration` / `declaration_from_descriptor`，
  CLI `build` / `declare`；命名 flags、嵌套集合、显式宽度和字节无损往返。
  声明 v1 与展示 JSON v2 是两个独立 schema。
- [批量帧重放](replay.md)：CLI `replay` 保留原行号、坏帧后继续，`--expect` 比较
  Usage 数值、Raw、物理量和活跃集合；Xbox 42 帧使用既有独立期望。
- [`transport` 帧转换](hidapi.md)：纯 MoonBit 四后端包，在核心 wire、HIDAPI 缓冲区和
  WebHID ID/payload 之间转换并验证前缀、ID 与精确长度。
- [一键验收](acceptance.md)、[设计](design.md)、[实际 AI 协作说明](ai-collaboration.md)，
  以及覆盖所有 Release 正文和额外清单的公开链接核验。

## 安装与复现

```sh
moon add We1chan/moonhid@0.6.0
```

从固定标签克隆源码并完整验收：

```sh
git clone --branch v0.6.0 https://github.com/We1chan/moonhid.git
cd moonhid
moon update
node scripts/acceptance.mjs
```

依赖齐全时汇总为 `PASS 23 / FAIL 0 / SKIP 0`；缺少可选依赖会明确显示 SKIP。
四后端源码各 123 项测试。完整条件和日志字段见 [验收说明](acceptance.md)。

注册表独立验收在仓库外创建新项目，不允许本地路径覆盖，
[14 项公开 API 测试](registry-0.6.0-test.mbt.txt) 包含新声明和帧转换，以及原有 Buffered Bytes、
字段/Usage/物理量、三方向和 Raw 边界。发布后执行：

```sh
node scripts/verify-registry.mjs
node scripts/check-public-docs.mjs --urls docs/acceptance-urls.txt
```

`verify-registry` 记录实际下载的版本、四后端结果，并逐文件比较安装包和 `v0.6.0` Git 对象；
原始 SHA 与 LF 归一比较分开。输出为 `docs/registry-0.6.0-validation.json`。
公开链接检查消费两站实际渲染的 href，通过 `gh api` 分页读取所有 Release 正文，
再检查 [额外入口清单](acceptance-urls.txt)。额外文件支持每行一个 HTTP(S) URL、空行/`#` 注释，
或 JSON 字符串数组。需要 GitHub CLI；CI 使用只读的仓库令牌。结果写入 `_build/public-docs-report.json`。

发布前的源码/CI、发布后的注册表/链接与下载包结果分别记录。
最终机器记录随 [v0.6.0 Release](https://github.com/We1chan/moonhid/releases/tag/v0.6.0) 附件提供；
不能把发布准备或本地路径导入当成独立安装通过。

## 兼容性与证据边界

已有核心函数与展示 JSON v2 保持兼容，新增声明诊断和独立帧转换包。
从 0.4.0 升级且手工构造 `DecodedReport` 时，仍需包含 `buffered_values: []`。
标准范围与 33 位 Raw 宽松扩展继续分开，见 [兼容目标](hid-compatibility.md) 和 [报告案例](report-cases.md)。

HIDAPI 只完成 Windows 0.15.0 / Linux 0.14.0 原生链接、初始化，以及 Linux CI 的 UHID 创建/枚举探针；
原生设备收发适配器、完整 UHID 收发、实机键盘 LED/Feature 和可选网页 Output/Feature 发送仍在规划中。
Xbox 数据只说明既有主机 Input 观测。参赛者对核心设计的独立理解尚未验证，AI 说明如实披露此状态。

## 离线交付

Release 附带 `moonhid-inspector-v0.6.0.zip` 和 `SHA256SUMS.txt`。
解压后运行 `node scripts/serve-offline.mjs`，Windows 也可双击 `start-inspector.cmd`；只需 Node.js 22+。
`BUILD.json` 记录版本、构建提交和时间。下载后对照 SHA-256，并在解压包上运行服务复核。
在线检查器位于 [GitHub Pages](https://we1chan.github.io/moonhid/)，部署以对应 main CI 成功记录为准。

## 2026-10-23 实际交付验收

发布提交为 `706ff87a88ae166cc627c1bc1d0ca774e00ebe57`，Mooncakes 返回 `200 OK`，
[GitHub v0.6.0](https://github.com/We1chan/moonhid/releases/tag/v0.6.0) 已公开。
完整机器记录见 [发布汇总](release-0.6.0-validation.json) 和 [注册表独立安装](registry-0.6.0-validation.json)，
同时随 Release 附件提供，固定标签中的发布流程也能通过附件访问实际结果。

| 检查 | 实际结果 |
| --- | --- |
| 发布前 PR 与发布提交 CI | 各五项全绿；[发布提交 CI](https://github.com/We1chan/moonhid/actions/runs/39815335313) 使用手动触发，同一提交运行全部检查 |
| 干净克隆完整验收 | 原仓库外新克隆，`dirty: false`；PASS 23 / FAIL 0 / SKIP 0，四后端各 123/123 |
| 注册表独立安装 | 实际下载 0.6.0，无本地覆盖；四后端各 14/14；71 份源码/配置与标签原始字节、LF 归一比较均相同 |
| 公开交付链接 | GitHub/Mooncakes、全部 6 个 Release 正文和 9 个技术入口，共 296 个来源、102 个不同 URL；0 失败，0 缺失必需入口 |
| 下载离线包 | 从 GitHub 重新下载，SHA-256 与本地及下载的清单一致；17 个文件与上传构建逐字节相同 |
| 下载包运行 | Node-only 服务、资源/MIME/HEAD/路径限制、字段编辑通过；三方向 Buffered Bytes 和 13 位 Feature 值 4660 通过 |
| 线上检查器 | [Pages build/deploy](https://github.com/We1chan/moonhid/actions/runs/39817365525) 成功；线上 index/app/core 均为 HTTP 200，与下载包对应文件逐字节相同 |

GitHub 当时存在队列延迟，未观察到此提交的自动 push 检查；发布前 PR 已通过五项 CI，
且其 Git 树与发布提交相同。随后对发布提交手动运行完整 CI 和 Pages，均已拿到成功结果。
首次 Release 发布触发的 [公开文档 CI](https://github.com/We1chan/moonhid/actions/runs/39816618874) 也成功，
增加发布机器记录与 CI/Pages 链接后，本机再次检查全部 296 项并通过。

离线 ZIP SHA-256：

```text
d17b2ca18be8f0450ee9352aefbcf71b99826e640214227875c024c22ead15b8
```
